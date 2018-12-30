/*
 *  Uzebox Square Kernel
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
; This is the main program file of Square Kernel
;


#include "sq_int_defines.h"


;
; Fixed layout data
;

; --- 0x0100 - 0x029F Linker allocated for User
; --- 0x02A0 - 0x02DF 2 RAM tiles (0x15 - 0x16), only used for superwide
.set sq_ramtiles_base, 0x02A0
; --- 0x02E0 - 0x0D7F 85 RAM tiles (0x17 - 0x6B)
; --- 0x0D80 - 0x0F1F Region only used when Tiled display is active ---
.set sq_tile_rows,     0x0D80  ; 104b, Tile row configurations (26 x 1+3 bytes)
.set sq_video_yshift,  0x0D80  ;   1b, Video Y shift 0 - 7 pixels
.set sq_tileset_pth,   0x0D84  ;   1b, Tileset pointer high
.set sq_maskset_pth,   0x0D88  ;   1b, Mask set pointer high
.set sq_maskdat_pth,   0x0D8C  ;   1b, Mask data pointer high
.set sq_sptile_nfr,    0x0D90  ;   1b, Next free RAM tile for sprites
.set sq_map_bank,      0x0D94  ;   1b, Map extension, SPI RAM bank
.set sq_map_width,     0x0DE8  ;   2b, Map extension, width
.set sq_map_height,    0x0DEA  ;   2b, Map extension, height
.set sq_map_xpos,      0x0DEC  ;   2b, Map extension, current X position
.set sq_map_ypos,      0x0DEE  ;   2b, Map extension, current Y position
.set sq_pal_tiled,     0x0DF0  ;  16b, Palette for Tiled region (top)
.set sq_ramt_list,     0x0E00  ; 256b, RAM tile allocation chained lists
.set sq_ramt_list_ent, 0x0F00  ;  26b, RAM tile allocation list entries
.set sq_map_ptr,       0x0F1A  ;   2b, Map extension, start in SPI RAM
                               ;   4b, Free for Tiled
; --- 0x0F20 - 0x10FF Always used region ---
.set sq_pal_bitmap,    0x0F20  ;  16b, Palette for Bitmap region (bottom)
.set sq_color0_ptr,    0x0F30  ;   2b, Color 0 replacement map pointer
.set sq_frame_func,    0x0F32  ;   2b, Video frame function
.set sq_mix_buf,       0x0F34  ; 202b, Mix buffer
.set sq_mix_buf_wr,    0x0FFE  ;   1b, Mix buffer write pointer
.set sq_mix_buf_rd,    0x0FFF  ;   1b, Mix buffer read pointer
.set sq_ch0_struct,    0x1000  ;  16b, Channel 0 mixer structure
.set sq_ch1_struct,    0x1010  ;  16b, Channel 1 mixer structure
.set sq_ch2_struct,    0x1020  ;  16b, Channel 2 mixer structure
.set ch0_pos,          0x1030  ;   2b, IT; Channel 0 wave position
.set ch0_wave,         0x1032  ;   1b, IT; Channel 0 waveform
.set ch0_curvol,       0x1033  ;   1b, IT; Channel 0 current volume
.set ch0_step,         0x1034  ;   2b, IT; Channel 0 step (for frequency)
.set ch1_pos,          0x1036  ;   2b, IT; Channel 1 wave position
.set ch1_wave,         0x1038  ;   1b, IT; Channel 1 waveform
.set ch1_curvol,       0x1039  ;   1b, IT; Channel 1 current volume
.set ch1_step,         0x103A  ;   2b, IT; Channel 1 step (for frequency)
.set ch2_pos,          0x103C  ;   2b, IT; Channel 2 wave position
.set ch2_wave,         0x103E  ;   1b, IT; Channel 2 waveform
.set ch2_curvol,       0x103F  ;   1b, IT; Channel 2 current volume
.set ch2_step,         0x1040  ;   2b, IT; Channel 2 step (for frequency)
.set ch2_ampos,        0x1042  ;   2b, IT; Channel 2 AM wave position
.set ch2_amwave,       0x1044  ;   1b, IT; Channel 2 AM waveform
.set ch2_amstr,        0x1045  ;   1b, IT; Channel 2 AM strength
.set ch2_amstep,       0x1046  ;   2b, IT; Channel 2 AM step (for frequency)
.set ch2_prvvol,       0x1048  ;   1b, IT; Channel 2 prev. volume (for ramping)
.set sq_mix_vramp,     0x1049  ;   1b, IT; Volume ramping counter
.set joypad1_stat_t,   0x104A  ;   2b, Joypad 1 button state prep. in VSync
.set joypad2_stat_t,   0x104C  ;   2b, Joypad 2 button state prep. in VSync
.set sq_joypad1_stat,  0x104E  ;   2b, Joypad 1 button states
.set sq_joypad2_stat,  0x1050  ;   2b, Joypad 2 button states
.set video_jtab_lo,    0x1052  ;   1b, Next jump table entry in HSync IT
.set video_doff_lctr,  0x1053  ;   1b, Line counter for Display OFF lines
.set sq_frame_counter, 0x1054  ;   1b, Frame counter
.set sq_bitmap_bank,   0x1055  ;   1b, SPI RAM bitmap bank
.set sq_bitmap_ptr,    0x1056  ;   2b, SPI RAM bitmap pointer
.set sq_video_split,   0x1058  ;   1b, Video split point (tiled vs. bitmap)
.set sq_fs_return,     0x1059  ;   1b, Result of FS_Init()
.set sq_fs_struct,     0x105A  ;  23b, Filesystem structure for FS routines
.set bops_xpos,        0x1071  ;   1b, Bitmap op. scheduler XPos
.set bops_ypos,        0x1072  ;   1b, Bitmap op. scheduler YPos
.set bops_width,       0x1073  ;   1b, Bitmap op. scheduler Width
.set bops_height,      0x1074  ;   1b, Bitmap op. scheduler Height
.set bops_addrcmap,    0x1075  ;   4b, Bitmap op. scheduler Address & Colormap
.set bops_flags,       0x1079  ;   1b, Bitmap op. scheduler Flags
.set sq_coltab_pth,    0x107A  ;   1b, Sprite recolor table set pointer, high
.set sq_sptile_max,    0x107B  ;   1b, Maximum RAM tile count for sprites
.set sq_video_shrink,  0x107C  ;   1b, Video vertical shrink pixels (top & bottom)
.set sq_video_alines,  0x107D  ;   1b, Active tile lines
.set sq_patchset_ptr,  0x107E  ;   2b, Patch set pointer

.set sq_stackend,      0x1080  ;    -, User stack end

.set vm_tmp0,          0x1080  ;   1b, Temporary for Video Mode
.set vm_col0_ptr,      0x1081  ;   2b, Current Color 0 reload pointer
.set sq_video_lbuf,    0x1083  ; 104b, Video line buffer

;
; Super-wide mode for 232 x 200 images:
;
; The RAM tile & the Tiled display region is combined into one contiguous
; memory block, 3200 bytes. This is used to provide the extra pixels for the
; increased width. The layout is a bit weird as the entire 232 pixels width
; has to use SPI loads, so on the sides RAM data bytes will interleave with
; stuff directly fetched from SPI.
;

;
; Stack top, area shared with Video line buffer
;

.set stack_top,        0x10FF

;
; Exported symbols for C interface access
;
.global sq_frame_func
.global sq_pal_tiled
.global sq_pal_bitmap
.global sq_fs_return
.global sq_fs_struct
.global sq_ramtiles_base
.global sq_joypad1_stat
.global sq_joypad2_stat
.global sq_bitmap_bank
.global sq_bitmap_ptr
.global sq_color0_ptr

;
; Mixer structure fields
;

.set chs_pbase_idx,  0 ; Patch (instrument) base index (in patch set)
.set chs_flags,      1 ; Flags:
                       ; bit0: Active (Note ON) if set. Clearing enters release stage
                       ; bit1: Reset position & AM if set (auto-clears).
                       ; bit2: AM note is independent of Note if set.
                       ;       Otherwise depends (relative to it), sweeps too.
                       ; bit3: Tremolo if clear, AM if set.
                       ; bit4-7: Loop counter for loop patch command
.set chs_pcur_idx,   2 ; Current patch index (0xFF: Channel is silent)
.set chs_prem_tim,   3 ; Remaining ticks from current patch
.set chs_evol,       4 ; Envelope volume
.set chs_evol_adj,   5 ; Signed adjustment for Envelope vol. in each 60Hz tick
.set chs_nvol,       6 ; Note volume
.set chs_cvol,       7 ; Channel volume (0 - 128 normally, up to 255 for ch2)
.set chs_note_frac,  8 ; Note fraction for frequency sweeps
.set chs_note,       9 ; Note
.set chs_note_adjf, 10 ; Signed adjustment for Note in each 60Hz tick, fraction
.set chs_note_adj,  11 ; Signed adjustment for Note in each 60Hz tick
.set chs_wave,      12 ; Waveform
.set chs_am_level,  13 ; AM level (strength), only effective for Ch2
.set chs_am_wave,   14 ; AM waveform, only effective for Ch2
.set chs_am_note,   15 ; AM note (signed rel. to Note if flag set), only effective for Ch2
.set chs_tr_level,  13 ; Tremolo level
.set chs_tr_rate,   14 ; Tremolo rate
.set chs_tr_pos,    15 ; Tremolo position



.section .sq_tiny_text0


;
; EEPROM Block 0 contents
;
eeprom_format_table:

	.byte (EEPROM_SIGNATURE & 0xFF)
	.byte (EEPROM_SIGNATURE >> 8)
	.byte EEPROM_HEADER_VER
	.byte EEPROM_BLOCK_SIZE
	.byte EEPROM_HEADER_SIZE
	.byte 1                ; 0x05: HardwareVersion
	.byte 0                ; 0x06: HardwareRevision
	.byte 0x38, 0x08       ; 0x07: Standard uzebox & fuzebox features
	.byte 0, 0             ; 0x09: Extended features
	.byte 0, 0, 0, 0, 0, 0 ; 0x0B: MAC
	.byte 0                ; 0x11: ColorCorrectionType
	.byte 0, 0, 0, 0       ; 0x12: Game CRC
	.byte 0                ; 0x16: Bootloader flags
	.byte 0                ; 0x17: Unused
	.byte 0                ; 0x18: Graphics mode flags
	.byte 0                ; 0x19: Last selected game in the bootloader
	.byte 0, 0, 0, 0, 0, 0 ; reserved



;
; I/O initialization table. Values are in pairs to support setting up ports
; guarded by 4 cycle timeouts. List end has to be at the start of a pair.
;
io_table:

	.byte _SFR_MEM_ADDR(MCUSR),  0x00  ; Clear reset cause to allow turning WD off
	.byte _SFR_MEM_ADDR(GPIOR0), 0x01  ; Init GPIOR0 (for video, display disabled)

	.byte _SFR_MEM_ADDR(WDTCSR), (1 << WDCE) | (1 << WDE)
	.byte _SFR_MEM_ADDR(WDTCSR), 0x00  ; Turn off Watchdog (prescaler at 16ms)

	.byte _SFR_MEM_ADDR(CLKPR),  (1 << CLKPCE)
	.byte _SFR_MEM_ADDR(CLKPR),  0x00  ; Make sure running with no prescaler

	.byte _SFR_MEM_ADDR(SPL),    (stack_top & 0xFF)
	.byte _SFR_MEM_ADDR(SPH),    (stack_top >> 8) ; Stack location

	.byte _SFR_MEM_ADDR(TCCR1B), 0x00  ; Stop timers
	.byte _SFR_MEM_ADDR(TCCR0B), 0x00

	.byte _SFR_MEM_ADDR(PRR),    (1 << PRTWI) | (1 << PRADC) ; Turn off TWI and ADC (not used in a Uzebox)
	.byte _SFR_MEM_ADDR(DDRC),   0xFF  ; Video DAC

	.byte _SFR_MEM_ADDR(DDRD),   (1 << PD7) | (1 << PD6) | (1 << PD4) | (1 << PD1) ; Audio-out, Chip Select, LED, UART TX
	.byte _SFR_MEM_ADDR(PORTD),  (1 << PD6) | (1 << PD4) | (1 << PD5) | (1 << PD3) | (1 << PD2) | (1 << PD0) ; Set CS high, LED on, pull-up for all inputs (PD3, PD2 are buttons)

	; Setup port A for joypads
	.byte _SFR_MEM_ADDR(DDRA),   0x1C  ; Set only control lines (CLK, Latch) and SPI RAM chip select as outputs
	.byte _SFR_MEM_ADDR(PORTA),  0xFB  ; Activate pullups on the data lines and unused pins

	; Set up video timing according to display lines (136 cycles LOW pulses)
	.byte _SFR_MEM_ADDR(TCNT1H), 0
	.byte _SFR_MEM_ADDR(TCNT1L), 0

	.byte _SFR_MEM_ADDR(OCR1AH), (1819 >> 8)
	.byte _SFR_MEM_ADDR(OCR1AL), (1819 & 0xFF)

	.byte _SFR_MEM_ADDR(TCCR1B), (1 << WGM12) + (1 << CS10) ; CTC mode, use OCR1A for match
	.byte _SFR_MEM_ADDR(TIMSK1), (1 << OCIE1A)              ; Generate interrupt on match

	; Set clock divider counter for AD725 on TIMER0
	; Outputs 14.31818Mhz (4FSC)
	.byte _SFR_MEM_ADDR(TCCR0A), (1 << COM0A0) + (1 << WGM01) ; toggle on compare match + CTC
	.byte _SFR_MEM_ADDR(OCR0A),  0     ; Divide main clock by 2

	.byte _SFR_MEM_ADDR(TCCR0B), (1 << CS00) ; Enable timer, no pre-scaler

	; Set sound PWM on TIMER2
	.byte _SFR_MEM_ADDR(TCCR2A), (1 << COM2A1) + (1 << WGM21) + (1 << WGM20) ; Fast PWM

	.byte _SFR_MEM_ADDR(OCR2A),  0x80  ; Duty cycle (amplitude)
	.byte _SFR_MEM_ADDR(TCCR2B), (1 << CS20) ; Enable timer, no pre-scaler

	.byte _SFR_MEM_ADDR(DDRB),   (1 << SYNC_PIN) | (1 << VIDEOCE_PIN) | (1 << PB3) | (1 << PB7) | (1 << PB5) ; 4FSC, SCK, MOSI
	.byte _SFR_MEM_ADDR(PORTB),  (1 << SYNC_PIN) | (1 << VIDEOCE_PIN) | (1 << PB6) | (1 << PB2) | (1 << PB1) ; Set sync & chip enable line to hi, MISO and unused pins pull-up

	; End of list
	.byte 0xFF, 0xFF



;
; Default color remapping table for the sprite blitter (aligned to 256b)
;
.section .sq_coltab_default
sq_coltab_default:

	.byte 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15



;
; Interrupt vector table
;

.section .sq_vectors

	jmp   init_kernel          ; Vector0, Boot
	                           ;
	rjmp  .-2                  ; Vector1, INT0_vect (no use in Uzebox)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector2, INT1_vect (no use in Uzebox)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector3, INT2_vect (no use in Uzebox)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector4, PCINT0_vect (no use in Uzebox)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector5, PCINT1_vect (no use in Uzebox)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector6, PCINT2_vect (no use in Uzebox)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector7, PCINT3_vect (no use in Uzebox)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector8, WDT_vect (no use in Uzebox)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector9, TIMER2_COMPA_vect (Timer2 is used for Audio PWM)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector10, TIMER2_COMPB_vect (Timer2 is used for Audio PWM)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector11, TIMER2_OVF_vect (Timer2 is used for Audio PWM)
	rjmp  .-2                  ;
	rjmp  .-2                  ; Vector12, TIMER1_CAPT_vect (Timer1 is the main Video timer)
	rjmp  .-2                  ;
	rjmp  TIMER1_COMPA_vect    ; Vector13, TIMER1_COMPA_vect, this is the kernel's main interrupt
	rjmp  .-2                  ;

;
; Video Mode code provides further vectors
;

#include "sq_vm0_it.s"

;	rjmp  .-2                  ; Vector14, TIMER1_COMPB_vect, may be used by a video mode as needed
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector15, TIMER1_OVF_vect, may be used by a video mode as needed
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector16, TIMER0_COMPA_vect (Timer0 is used for AD725 clock in NTSC Uzebox)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector17, TIMER0_COMPB_vect (Timer0 is used for AD725 clock in NTSC Uzebox)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector18, TIMER0_OVF_vect (Timer0 is used for AD725 clock in NTSC Uzebox)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector19, SPI_STC_vect (no use in Uzebox)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector20, USART0_RX_vect (no use in Uzebox, UART is polled in scanline IT)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector21, USART0_UDRE_vect (no use in Uzebox, UART is polled in scanline IT)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector22, USART0_TX_vect (no use in Uzebox, UART is polled in scanline IT)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector23, ANALOG_COMP_vect (no use in Uzebox)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector24, ADC_vect (no use in Uzebox)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector25, EE_READY_vect (no use in Uzebox)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector26, TWI_vect (no use in Uzebox)
;	rjmp  .-2                  ;
;	rjmp  .-2                  ; Vector27, SPM_READY_vect (no use in Uzebox)



.section .init0



;
; Kernel initialization (init0 is not used by C init sequence, so this
; workaround passes, the C environment still gets initialized).
;
init_kernel:

	; Clear r1 and SREG (interrupts disabled)

	clr   r1
	out   _SFR_IO_ADDR(SREG), r1

	; Initialize I/O registers

	wdr
	ldi   ZL,      lo8(io_table)
	ldi   ZH,      hi8(io_table)
	ldi   XH,      0x00
	ldi   YH,      0x00
initialize_ioloop:
	lpm   XL,      Z+
	lpm   r2,      Z+
	lpm   YL,      Z+
	lpm   r3,      Z+
	cpi   XL,      0xFF
	breq  initialize_ioloop_end
	st    X,       r2
	st    Y,       r3
	rjmp  initialize_ioloop
initialize_ioloop_end:

	; Get a clean start: Zero all RAM (9K cycles).

	ldi   r18,     0
	ldi   XL,      0x00
	ldi   XH,      0x01
initialize_rzloop:
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	st    X+,      r1
	dec   r18
	brne  initialize_rzloop

	; Set up video. Start somewhere near VSync, possibly allowing for the
	; TV to sync faster. Video is disabled (as enabling would demand a
	; routine to call at frame reset to be set up), so screen is blank,
	; all CPU is user (excluding HSyncs). Volumes are zero all around, so
	; audio should produce silence.

	ldi   ZL,      0x01    ; Video Diabled
	out   _SFR_IO_ADDR(GPIOR0), ZL
	ldi   ZL,      33      ; Line 232, Plays sample 201, starts VBlank gen.
	sts   video_jtab_lo, ZL
	ldi   ZL,      0x80    ; First sample output should be silence
	sts   sq_mix_buf + 201, ZL
	ldi   ZL,      lo8(sq_mix_buf + 201)
	sts   sq_mix_buf_rd, ZL  ; Read & Write positions also set up accordingly
	ldi   ZL,      lo8(sq_mix_buf + 142)
	sts   sq_mix_buf_wr, ZL
	ldi   ZL,      0x8A    ; Set up stack guard, 0
	sts   sq_stackend + 0, ZL
	ldi   ZL,      0x17    ; Set up stack guard, 1
	sts   sq_stackend + 1, ZL

	ldi   ZL,      (1 << OCF1A)
	sts   _SFR_MEM_ADDR(TIFR1), ZL
	sei                    ; Video signal is generated from now (piled up IT reqs. cleaned up first)

	; Other initializations

	ldi   ZH,      hi8(sq_coltab_default)
	sts   sq_coltab_pth, ZH  ; Start with a reasonable initial sprite color remapping table
	ldi   ZH,      85
	sts   sq_sptile_max, ZH  ; Start with 85 RAM tiles allowed for the sprite engine

	; Audio system

	call  SQ_AudioCutOff
	ldi   r24,     lo8(sq_defpatches)
	ldi   r25,     hi8(sq_defpatches)
	call  SQ_SetPatchSet
	ldi   r24,     0
	ldi   r22,     128
	call  SQ_SetChannelVolume
	ldi   r24,     1
	ldi   r22,     128
	call  SQ_SetChannelVolume
	ldi   r24,     2
	ldi   r22,     128
	call  SQ_SetChannelVolume



.section .init8

;
; All ready to go, some extra tasks to get everything initialized proper.
;

	; Format EEPROM if necessary

	call  SQ_FormatEeprom

	; Initialize SD card

	ldi   r24,     lo8(sq_ramtiles_base)
	ldi   r25,     hi8(sq_ramtiles_base)
	sts   sq_fs_struct + 1, r24 ; bufp; Sector buffer, low
	sts   sq_fs_struct + 2, r25 ; bufp; Sector buffer, high
	ldi   r24,     lo8(sq_fs_struct)
	ldi   r25,     hi8(sq_fs_struct)
	call  FS_Init
	sts   sq_fs_return, r24

	; Initialize SPI RAM

	call  XRAM_Init



.section .text



;
; Copies memory, source can be ROM / RAM.
;
; void* SQ_MEM_Copy(void* dst, void const* src, uint16_t len);
;
; r25:r24: Destination pointer
; r23:r22: Source pointer
; r21:r20: Length
; Return:
; r25:r24: Destination pointer
;
.global SQ_MEM_Copy
.section .text.SQ_MEM_Copy
SQ_MEM_Copy:

	movw  XL,      r24
	movw  ZL,      r22
	mov   r22,     r20
	or    r22,     r21
	breq  2f               ; Zero length: Return
	cpi   ZH,      0x11
	brcc  3f

	; <  0x1100: RAM source

	sbrs  r20,     0
	rjmp  0f
	subi  r20,     0xFF
	sbci  r21,     0xFF
	rjmp  1f
0:
	ld    r23,     Z+
	st    X+,      r23
1:
	ld    r23,     Z+
	st    X+,      r23
	subi  r20,     2
	sbci  r21,     0
	brne  0b
2:
	ret

3:
	; >= 0x1100: ROM source

	sbrs  r20,     0
	rjmp  0f
	subi  r20,     0xFF
	sbci  r21,     0xFF
	rjmp  1f
0:
	lpm   r23,     Z+
	st    X+,      r23
1:
	lpm   r23,     Z+
	st    X+,      r23
	subi  r20,     2
	sbci  r21,     0
	brne  0b
	ret



;
; Copies memory to XRAM, source can be ROM / RAM.
;
; void  SQ_XRAM_MEM_Copy(uint8_t dstbank, uint16_t dstoff, void const* src, uint16_t len);
;
;     r24: Destination bank
; r23:r22: Destination pointer
; r21:r20: Source pointer
; r19:r18: Length
;
.global SQ_XRAM_MEM_Copy
.section .text.SQ_XRAM_MEM_Copy
SQ_XRAM_MEM_Copy:

	mov   r25,     r20
	or    r25,     r21
	breq  0f               ; Zero length: Return
	cpi   r21,     0x11
	brcc  1f

	; <  0x1100: RAM source

	jmp   XRAM_WriteFrom
0:
	ret

1:
	; >= 0x1100: ROM source

	push  r17
	push  r16
	push  YH
	push  YL
	movw  YL,      r18     ; YH:YL: Length (remaining)
	movw  r16,     r20     ; r17:r16: Source (ROM) pointer
	call  XRAM_SeqWriteStart
0:
	movw  ZL,      r16
	lpm   r24,     Z+
	movw  r16,     ZL
	call  XRAM_SeqWriteU8
	sbiw  YL,      1
	brne  0b
	pop   YL
	pop   YH
	pop   r16
	pop   r17
	jmp   XRAM_SeqWriteEnd



;
; Reset (usually returns to bootloader)
;
; void SQ_Reset(void) __attribute__((noreturn));
;
.global SQ_Reset
.section .text.SQ_Reset
SQ_Reset:

	; First check whether the watchdog is already running, if so, return.
	; This may happen if the soft reset is called from interrupt.
	; Note that no "wdr" is used, it is unnecessary. If the watchdog
	; resets right when it was enabled, that's all right.

	ldi   ZL,      lo8(_SFR_MEM_ADDR(WDTCSR))
	ldi   ZH,      hi8(_SFR_MEM_ADDR(WDTCSR))
	ld    r24,     Z
	sbrc  r24,     WDE     ; Watchdog already enabled?
	ret                    ; If so, return doing nothing (let it time out)
	ldi   r24,     (1 << WDCE) | (1 << WDE)
	ldi   r25,     (1 << WDE) ; Enable Watchdog, 16ms timeout
	cli
	st    Z,       r24
	st    Z,       r25
	sei
	rjmp  .-2              ; Halt user program



;
; Start and End, the former is intended as a termination of main(), the latter
; as the termination of the frame function. The distinction only matters for
; portability.
;
; void SQ_End(void) __attribute__((noreturn));
; void SQ_Start(void) __attribute__((noreturn));
;
.global SQ_End
.global SQ_Start
.section .text.SQ_StartEnd
SQ_End:
SQ_Start:

	cbi   _SFR_IO_ADDR(GPIOR0), 0 ; Enable display
	call  SQ_BOPScheduler  ; Run scheduled Bitmap Operation in remaining time
	rjmp  .-2              ; Might never ever be reached



;
; Enables video, calling this in the frame routine enables it being cut off
; by the video frame, maintaining a consistent 60Hz frame rate. May be used to
; cut off for example rendering if it exceeds the frame time.
;
; void SQ_VideoEnable(void);
;
.global SQ_VideoEnable
.section .text.SQ_VideoEnable
SQ_VideoEnable:

	cbi   _SFR_IO_ADDR(GPIOR0), 0 ; Enable display
	ret



;
; Checks whether a frame was skipped. Can be used to keep 60Hz sync even when
; frameskips happen.
;
; uint8_t SQ_IsFrameSkipped(void);
;
; Returns:
;     r24: 1 if a frame was skipped.
;
.global SQ_IsFrameSkipped
.section .text.SQ_IsFrameSkipped
SQ_IsFrameSkipped:

	ldi   r24,     0
	sbic  _SFR_IO_ADDR(GPIOR0), 1 ; Display frame happened (and skipped)?
	ldi   r24,     1
	ret



;
; Clears frame skipped flag so it may collect a subsequent frameskip.
;
; void SQ_ClearFrameSkipped(void);
;
.global SQ_ClearFrameSkipped
.section .text.SQ_ClearFrameSkipped
SQ_ClearFrameSkipped:

	cbi   _SFR_IO_ADDR(GPIOR0), 1 ; Clear the display frame skipped flag
	ret



;
; Load data from SD card into XRAM. A length of 0 loads 128K.
;
; uint8_t SQ_LoadData(sdc_struct_t* sds, uint8_t xrambank, uint16_t xramoff, uint8_t sectors);
;
; r25:r24: SD structure (passed to FS routines)
;     r22: XRAM bank (passed to XRAM routines)
; r21:r20: XRAM offset (passed to XRAM routines)
;     r18: Length in SD sectors (512b)
; Returns:
;     r24: Return of failing FS routine or 0 on success.
;
.global SQ_LoadData
.section .text.SQ_LoadData
SQ_LoadData:

	push  r17
	push  r16
	push  r15
	push  r14
	push  r13
	push  r12
	push  r11
	push  r10
	mov   r17,     r18     ; Length in sectors in r17
	mov   r16,     r22     ; XRAM bank in r16
	movw  r14,     r24     ; SD structure in r25:r24
	movw  r12,     r20     ; XRAM offset in r13:r12
	movw  ZL,      r24
	ldd   r10,     Z + 1
	ldd   r11,     Z + 2   ; Sector buffer ptr. in r11:r10

	; Copy loop

0:
	movw  r24,     r14
	call  FS_Read_Sector
	cpi   r24,     0
	brne  1f
	mov   r24,     r16
	movw  r22,     r12
	movw  r20,     r10
	ldi   r18,     0
	ldi   r19,     2       ; 512 bytes
	call  XRAM_WriteFrom
	inc   r13
	brne  .+2
	inc   r16
	inc   r13
	brne  .+2
	inc   r16              ; Next sector in XRAM (bank updated too as necessary)
	ldi   r24,     0       ; OK return
	dec   r17
	breq  1f
	movw  r24,     r14
	call  FS_Next_Sector
	cpi   r24,     0
	breq  0b
1:
	pop   r10
	pop   r11
	pop   r12
	pop   r13
	pop   r14
	pop   r15
	pop   r16
	pop   r17
	ret



;
; Save data to SD card from XRAM. A length of 0 saves 128K.
;
; uint8_t SQ_SaveData(sdc_struct_t* sds, uint8_t xrambank, uint16_t xramoff, uint8_t sectors);
;
; r25:r24: SD structure (passed to FS routines)
;     r22: XRAM bank (passed to XRAM routines)
; r21:r20: XRAM offset (passed to XRAM routines)
;     r18: Length in SD sectors (512b)
; Returns:
;     r24: Return of failing FS routine or 0 on success.
;
.global SQ_SaveData
.section .text.SQ_SaveData
SQ_SaveData:

	push  r17
	push  r16
	push  r15
	push  r14
	push  r13
	push  r12
	push  r11
	push  r10
	mov   r17,     r18     ; Length in sectors in r17
	mov   r16,     r22     ; XRAM bank in r16
	movw  r14,     r24     ; SD structure in r25:r24
	movw  r12,     r20     ; XRAM offset in r13:r12
	movw  ZL,      r24
	ldd   r10,     Z + 1
	ldd   r11,     Z + 2   ; Sector buffer ptr. in r11:r10

	; Copy loop

0:
	mov   r24,     r16
	movw  r22,     r12
	movw  r20,     r10
	ldi   r18,     0
	ldi   r19,     2       ; 512 bytes
	call  XRAM_ReadInto
	inc   r13
	brne  .+2
	inc   r16
	inc   r13
	brne  .+2
	inc   r16              ; Next sector in XRAM (bank updated too as necessary)
	ldi   r24,     0       ; OK return
	dec   r17
	breq  1f
	movw  r24,     r14
	call  FS_Write_Sector
	cpi   r24,     0
	brne  1f
	movw  r24,     r14
	call  FS_Next_Sector
	cpi   r24,     0
	breq  0b
1:
	pop   r10
	pop   r11
	pop   r12
	pop   r13
	pop   r14
	pop   r15
	pop   r16
	pop   r17
	ret



;
; Format EEPROM including setting up head block; only do this if necessary
; (EEPROM is not already formatted).
;
; void SQ_FormatEeprom(void);
;
.global SQ_FormatEeprom
.section .text.SQ_FormatEeprom
SQ_FormatEeprom:

	push  YL
	push  YH

	; Check whether EEPROM is formatted (2 byte signature is there)

	ldi   r24,     0x00     ; Pos. 0x0000 signature byte
	call  SQ_ReadEeprom_Head
	cpi   r24,     (EEPROM_SIGNATURE & 0xFF)
	brne  SQ_FormatEeprom_doformat
	ldi   r24,     0x01     ; Pos. 0x0001 signature byte
	call  SQ_ReadEeprom_Head
	cpi   r24,     (EEPROM_SIGNATURE >> 8)
	breq  SQ_FormatEeprom_end

SQ_FormatEeprom_doformat:

	; Write EEPROM header

	ldi   YL,      0
	ldi   YH,      0
SQ_FormatEeprom_headl:
	movw  ZL,      YL
	subi  ZL,      lo8(-(eeprom_format_table))
	sbci  ZH,      hi8(-(eeprom_format_table))
	movw  r24,     YL      ; r25:r24: Address
	lpm   r22,     Z       ; r22: Data
	call  SQ_WriteEeprom
	inc   YL
	cpi   YL,      EEPROM_BLOCK_SIZE * EEPROM_HEADER_SIZE
	brne  SQ_FormatEeprom_headl

	; Write block occupation info (all are free blocks)

SQ_FormatEeprom_blockl:
	movw  r24,     YL
	ldi   r22,     (EEPROM_FREE_BLOCK & 0xFF)
	call  SQ_WriteEeprom
	adiw  YL,      1
	movw  r24,     YL
	ldi   r22,     (EEPROM_FREE_BLOCK >> 8)
	call  SQ_WriteEeprom
	adiw  YL,      (EEPROM_BLOCK_SIZE - 1)
	cpi   YH,      (2048 >> 8)
	brne  SQ_FormatEeprom_blockl

	; Done

SQ_FormatEeprom_end:

	pop   YH
	pop   YL
	ret



;
; Write byte to EEPROM
;
; void SQ_WriteEeprom(uint16_t addr, uint8_t value);
;
; r25:r24: addr
;     r22: value to write
;
.global SQ_WriteEeprom
.section .text.SQ_WriteEeprom
SQ_WriteEeprom_Head:

	ldi   r25,     0       ; Write to EEPROM's beginning

SQ_WriteEeprom:

	; Check current byte at location (don't write if already OK)
	; This also waits previous write's end, so no need to check.

	movw  r20,     r24
	call  SQ_ReadEeprom
	cp    r24,     r22
	breq  SQ_WriteEeprom_ret

	; Set up address (r21:r20) in address register
	out   _SFR_IO_ADDR(EEARH), r21
	out   _SFR_IO_ADDR(EEARL), r20
	; Write data (r22) to Data Register
	out   _SFR_IO_ADDR(EEDR), r22
	cli
	; Write logical one to EEMPE
	sbi   _SFR_IO_ADDR(EECR), EEMPE
	; Start eeprom write by setting EEPE
	sbi   _SFR_IO_ADDR(EECR), EEPE
	sei

SQ_WriteEeprom_ret:

	ret



;
; Read byte from EEPROM
;
; uint8_t SQ_ReadEeprom(uint16_t addr);
;
; r25:r24: addr
; Returns:
;     r24: byte read
;
.global SQ_ReadEeprom
.section .text.SQ_ReadEeprom
SQ_ReadEeprom_Head:

	ldi   r25,     0       ; Read from EEPROM's beginning

SQ_ReadEeprom:

	; Wait for completion of previous write
	sbic  _SFR_IO_ADDR(EECR), EEPE
	rjmp  SQ_ReadEeprom
	; Set up address (r25:r24) in address register
	out   _SFR_IO_ADDR(EEARH), r25
	out   _SFR_IO_ADDR(EEARL), r24
	; Start eeprom read by writing EERE
	cli
	sbi   _SFR_IO_ADDR(EECR), EERE
	; Read data from Data Register
	in    r24,     _SFR_IO_ADDR(EEDR)
	sei
	ret



;
; Sets the onboard LED on PD4
;
; void SQ_SetLed(uint8_t val);
;
;     r24: Desired LED state (nonzero: ON)
;
.global SQ_SetLed
.section .text.SQ_SetLed
SQ_SetLed:
	cpi    r24,    0
	breq   .+4
	sbi   _SFR_IO_ADDR(PORTD), PD4
	ret
	cbi   _SFR_IO_ADDR(PORTD), PD4
	ret



;
; Toggles the onboard LED on PD4
;
; void SQ_ToggleLed(void);
;
.global SQ_ToggleLed
.section .text.SQ_ToggleLed
SQ_ToggleLed:
	sbi   _SFR_IO_ADDR(PIND), PD4
	ret



;
; Further components
;

#include "sq_auvid.s"
#include "sq_steptb.s"
#include "sq_sine.s"
#include "sq_aufunc.s"

;
; Video mode (the interrupt part is included into the vector table)
;

#include "sq_vm0.s"
#include "sq_vm0_func.s"
#include "sq_sprite.s"
#include "sq_map.s"

;
; Other modules
;

#include "bootlib.s"
#include "xram.s"
