/*
 *  Uzebox Square Kernel - Main header file
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


/*
** This header file can be used by C language games. The game only needs to
** include this.
*/


#ifndef SQ_KERNEL_H
#define SQ_KERNEL_H


#include <stdint.h>
#include <avr/pgmspace.h>
#include "xram.h"
#include "bootlib.h"


/*
** No-return function attribute (to allow for defining noreturn functions
** while opening possibility for easy porting where using noreturn is not
** feasible).
*/
#define SQ_NORETURN __attribute__((noreturn))

/*
** Sections for tilesets & waveforms & constants (program mem. stuff)
*/
#define SQ_SECTION_TILESET __attribute__((section(".romdata256")))
#define SQ_SECTION_WAVESET __attribute__((section(".romdata256")))
#define SQ_SECTION_CONST   PROGMEM


/*
** Assemble a 8 bit color from 8 bit RGB values
*/
#define SQ_COLOR8(r, g, b) (((r >> 5) & 0x07U) | ((g >> 2) & 0x38U) | ((b) & 0xC0U))


/*
** Tile row descriptor flags. XSHIFTMSK is a mask for X shift values
*/
#define SQ_TRD_XSHIFTMSK 0x07U
#define SQ_TRD_HIGHBANK  0x80U


/*
** Sprite engine flags.
*/
#define SQ_SPR_FLIPX     0x01U
#define SQ_SPR_FLIPY     0x04U
#define SQ_SPR_HIGHBANK  0x02U
#define SQ_SPR_MASK      0x10U


/*
** SNES controller buttons
*/
#define SQ_BUTTON_B      0x0001U
#define SQ_BUTTON_Y      0x0002U
#define SQ_BUTTON_SELECT 0x0004U
#define SQ_BUTTON_START  0x0008U
#define SQ_BUTTON_UP     0x0010U
#define SQ_BUTTON_DOWN   0x0020U
#define SQ_BUTTON_LEFT   0x0040U
#define SQ_BUTTON_RIGHT  0x0080U
#define SQ_BUTTON_A      0x0100U
#define SQ_BUTTON_X      0x0200U
#define SQ_BUTTON_SL     0x0400U
#define SQ_BUTTON_SR     0x0800U


/*
** The followings are private, must not be accessed directly
*/
extern void (*volatile sq_frame_func)(void);
extern uint8_t sq_pal_tiled[16];
extern uint8_t sq_pal_bitmap[16];
extern uint8_t sq_fs_return;
extern sdc_struct_t sq_fs_struct;
extern char sq_ramtiles_base[100U * 32U];
extern volatile uint16_t sq_joypad1_stat;
extern volatile uint16_t sq_joypad2_stat;
extern uint8_t  sq_bitmap_bank;
extern uint16_t sq_bitmap_ptr;
extern uint8_t const* sq_color0_ptr;


/*
** Public data
*/
extern const int8_t sq_sinewave[256] SQ_SECTION_WAVESET;


/*
** Public functions
*/
static inline int8_t SQ_Sin8(uint8_t x){ return (int8_t)(pgm_read_byte(&sq_sinewave[x])); }
static inline int8_t SQ_Cos8(uint8_t x){ return (int8_t)(pgm_read_byte(&sq_sinewave[(x + 64U) & 0xFFU])); }

static inline  uint8_t SQ_MEM_GetU8 ( uint8_t const* ptr){ if ((uint16_t)(ptr) < 0x1100U){ return *ptr; }else{ return ( uint8_t)(pgm_read_byte (ptr)); } }
static inline uint16_t SQ_MEM_GetU16(uint16_t const* ptr){ if ((uint16_t)(ptr) < 0x1100U){ return *ptr; }else{ return (uint16_t)(pgm_read_word (ptr)); } }
static inline uint32_t SQ_MEM_GetU32(uint32_t const* ptr){ if ((uint16_t)(ptr) < 0x1100U){ return *ptr; }else{ return (uint32_t)(pgm_read_dword(ptr)); } }
static inline   int8_t SQ_MEM_GetS8 (  int8_t const* ptr){ if ((uint16_t)(ptr) < 0x1100U){ return *ptr; }else{ return (  int8_t)(pgm_read_byte (ptr)); } }
static inline  int16_t SQ_MEM_GetS16( int16_t const* ptr){ if ((uint16_t)(ptr) < 0x1100U){ return *ptr; }else{ return ( int16_t)(pgm_read_word (ptr)); } }
static inline  int32_t SQ_MEM_GetS32( int32_t const* ptr){ if ((uint16_t)(ptr) < 0x1100U){ return *ptr; }else{ return ( int32_t)(pgm_read_dword(ptr)); } }

void* SQ_MEM_Copy(void* dst, void const* src, uint16_t len);
void  SQ_XRAM_MEM_Copy(uint8_t dstbank, uint16_t dstoff, void const* src, uint16_t len);

static inline uint8_t       SQ_GetFSReturn(void){ return sq_fs_return; }
static inline sdc_struct_t* SQ_GetFSStruct(void){ return &sq_fs_struct; }

static inline void* SQ_GetBlitterTilePtr(uint8_t tno){ return (void*)(&sq_ramtiles_base[(uint16_t)(tno) * 32U]); }

static inline uint16_t SQ_GetP1Buttons(void){ return sq_joypad1_stat; }
static inline uint16_t SQ_GetP2Buttons(void){ return sq_joypad2_stat; }

void SQ_Reset(void) SQ_NORETURN;

static inline void SQ_SetFrameFunc(void (*fptr)(void)){ sq_frame_func = fptr; }
void SQ_Start(void) SQ_NORETURN;
void SQ_End(void) SQ_NORETURN;
void SQ_VideoEnable(void);

uint8_t SQ_LoadData(sdc_struct_t* sds, uint8_t xrambank, uint16_t xramoff, uint8_t sectors);
uint8_t SQ_SaveData(sdc_struct_t* sds, uint8_t xrambank, uint16_t xramoff, uint8_t sectors);

static inline void SQ_SetTiledColor8(uint8_t idx, uint8_t val){ sq_pal_tiled[idx & 0xFU] = val; }
static inline void SQ_SetBitmapColor8(uint8_t idx, uint8_t val){ sq_pal_bitmap[idx & 0xFU] = val; }
void SQ_XRAM_SetTiledPal8(uint8_t srcbank, uint16_t srcoff);
void SQ_XRAM_SetBitmapPal8(uint8_t srcbank, uint16_t srcoff);
void SQ_MEM_SetTiledPal8(uint8_t const* ptr);
void SQ_MEM_SetBitmapPal8(uint8_t const* ptr);

void SQ_ClearSprites(void);
void SQ_BlitSprite(uint16_t xramoff, uint8_t xpos, uint8_t ypos, uint8_t flags);
void SQ_BlitSpriteCol(uint16_t xramoff, uint8_t xpos, uint8_t ypos, uint8_t flags, uint8_t coltabidx);
void SQ_SpritePixel(uint8_t col, uint8_t xpos, uint8_t ypos, uint8_t flags);
void SQ_SetSpriteColMaps(uint8_t const* ptr);
void SQ_SetMaxSpriteTiles(uint8_t count);

void SQ_SetTileset(uint8_t const* tileset, uint8_t const* maskset, uint8_t const* maskdata);
void SQ_SetTileRowDesc(uint8_t row, uint16_t bgoff, uint8_t flags);
void SQ_SetTileRowBGOff(uint8_t row, uint16_t bgoff, uint16_t xpos, uint8_t flags);
void SQ_SetTileDesc(uint16_t bgoff, uint16_t width, uint8_t flags);
void SQ_SetTileBGOff(uint16_t bgoff, uint16_t width, uint16_t xpos, uint16_t ypos, uint8_t flags);
void SQ_SetYShift(uint8_t yshift);

void SQ_MAP_Init(uint8_t xrambank, uint16_t xramoff, uint16_t width, uint16_t height);
void SQ_MAP_MoveTo(int16_t xpos, int16_t ypos);
void SQ_MAP_BlitSprite(uint16_t xramoff, int16_t xpos, int16_t ypos, uint8_t flags);
void SQ_MAP_BlitSpriteCol(uint16_t xramoff, int16_t xpos, int16_t ypos, uint8_t flags, uint8_t coltabidx);
void SQ_MAP_SpritePixel(uint8_t col, int16_t xpos, int16_t ypos, uint8_t flags);

void SQ_SetScreenSplit(uint8_t split);
void SQ_SetWideBitmap(void);
void SQ_SetScreenShrink(uint8_t shrink);
static inline void SQ_SetBitmapLocation(uint8_t xrambank, uint16_t xramoff){ sq_bitmap_bank = xrambank; sq_bitmap_ptr = xramoff; }
void SQ_SetBitmapC0Reload(uint8_t ena);
void SQ_SetTiledC0Reload(uint8_t ena);
static inline void SQ_SetC0Location(uint8_t const* ramptr){ sq_color0_ptr = ramptr; }

void SQ_PrepBitmap(uint8_t dstbank, uint16_t dstoff, uint8_t srcbank, uint16_t srcoff, uint16_t rowcnt, void* workram);
void SQ_PrepWideBitmap(uint8_t dstbank, uint16_t dstoff, uint8_t srcbank, uint16_t srcoff);

void SQ_MEM_BitmapBlit1(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t const* ptr, uint16_t colmap);
void SQ_MEM_BitmapBlit2(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t const* ptr, uint16_t colmap);
void SQ_XRAM_BitmapCopy(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t srcbank, uint16_t srcoff);

void SQ_MEM_BitmapBlit1Sched(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t const* ptr, uint16_t colmap);
void SQ_MEM_BitmapBlit2Sched(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t const* ptr, uint16_t colmap);
void SQ_XRAM_BitmapCopySched(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t srcbank, uint16_t srcoff);
uint8_t SQ_IsBitmapOpScheduled(void);

#endif
