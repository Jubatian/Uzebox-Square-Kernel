#include <sq_kernel.h>
#include <string.h>
#include "tiles.h"
#include "tiles_txt.h"



static uint16_t main_framectr = 0U;
static uint8_t  main_shrink = 0U;


static uint16_t charaddr(char chr)
{
 return 0x6000U + ((uint16_t)((uint8_t)(chr) - 32U) * 32U);
}


static uint8_t const colmaps[256] SQ_SECTION_TILESET = {
  0U,  1U,  2U,  3U,  4U,  5U,  6U,  7U,  8U,  9U, 10U, 11U, 12U, 13U, 14U, 15U,
  0U, 15U, 14U, 13U, 12U, 11U, 10U,  9U,  8U,  7U,  6U,  5U,  4U,  3U,  2U,  1U
};


void frame(void)
{
 uint8_t  x;
 uint8_t  y;
 uint16_t btn;

 main_framectr ++;

 btn = SQ_GetP1Buttons();
 if ( (btn & SQ_BUTTON_UP) &&
      (main_shrink >  0U) ){ main_shrink --; }
 if ( (btn & SQ_BUTTON_DOWN) &&
      (main_shrink < 50U) ){ main_shrink ++; }
 SQ_SetScreenShrink(main_shrink);

 x = (uint8_t)(SQ_Sin8(main_framectr >> 1)) + 128U;
 y = (uint8_t)(SQ_Cos8(main_framectr >> 1)) + 128U;

 if ((main_framectr & 0x700U) == 0x300U){
  SQ_SetScreenSplit((0xFFU - main_framectr) & 0xFFU);
 }
 if ((main_framectr & 0x700U) == 0x500U){
  SQ_SetScreenSplit((        main_framectr) & 0xFFU);
 }

 SQ_MAP_MoveTo(x, y);

 SQ_ClearSprites();

 SQ_VideoEnable(); // From now, stuff may be cut off

 SQ_MAP_BlitSprite(charaddr('M'), 150, 150, 0U);
 SQ_MAP_BlitSprite(charaddr('M'), 300, 150, 0U);
 SQ_MAP_BlitSprite(charaddr('M'), 300, 300, 0U);

 SQ_BlitSprite(charaddr('0'), 100, 10, 0U);
 SQ_BlitSprite(charaddr('1'), 10, 10, 0U);
 SQ_BlitSprite(charaddr('2'), 50, 10, 0U);

 SQ_BlitSprite(charaddr('3'), 100, 50, SQ_SPR_FLIPX);
 SQ_BlitSprite(charaddr('4'), 10, 50, SQ_SPR_FLIPX);
 SQ_BlitSprite(charaddr('5'), 50, 50, SQ_SPR_FLIPX);

 SQ_BlitSprite(charaddr('6'), 150, 8, 0U);
 SQ_BlitSprite(charaddr('7'), 160, 8, 0U);
 SQ_BlitSprite(charaddr('8'), 170, 8, 0U);

 SQ_BlitSprite(charaddr('9'), 150, 200, 0U);
 SQ_BlitSprite(charaddr('!'), 160, 200, 0U);
 SQ_BlitSprite(charaddr('?'), 170, 200, 0U);

 SQ_BlitSprite(charaddr('S'), x, y, 0U);

 for (x = 0U; x < 22U; x ++){
  SQ_BlitSpriteCol(charaddr('A' + x), (x * 9U) + 8U, 70, SQ_SPR_FLIPX | SQ_SPR_FLIPY, 16U);
  SQ_MAP_BlitSpriteCol(charaddr('A' + x), (x * 8U) + 88U,  88U, SQ_SPR_FLIPX | SQ_SPR_FLIPY, 0U);
//  SQ_MAP_BlitSpriteCol(charaddr('A' + x), (x * 8U) + 88U,  96U, SQ_SPR_FLIPX | SQ_SPR_FLIPY, 0U);
//  SQ_MAP_BlitSpriteCol(charaddr('A' + x), (x * 8U) + 88U, 104U, SQ_SPR_FLIPX | SQ_SPR_FLIPY, 0U);
//  SQ_MAP_BlitSpriteCol(charaddr('A' + x), (x * 8U) + 88U, 112U, SQ_SPR_FLIPX | SQ_SPR_FLIPY, 0U);
 }

 SQ_MAP_BlitSprite(charaddr('A'), 160, 160, 0U);

}



int main(void)
{
 uint32_t cluster;

 cluster = FS_Find(SQ_GetFSStruct(),
                   FS_FIND_NAME('C','H','W','Y','V','E','R','N','D','A','T'));

 if (cluster != 0U){
  FS_Select_Cluster(SQ_GetFSStruct(), cluster);
  SQ_LoadData(SQ_GetFSStruct(), 1U, 0U, 64U);
  SQ_PrepBitmap(1U, 2U + 2U + 16U, 200U, SQ_GetBlitterTilePtr(0));
  SQ_XRAM_SetBitmapPal8(1U, 2U + 2U);
 }

 SQ_SetFrameFunc(&frame);

 SQ_XRAM_MEM_Copy(0U, 0x5000U, tiles_map, 64U * 64U);
 SQ_XRAM_MEM_Copy(0U, 0x6000U, tiles_txt, 2048U);
 SQ_SetTileset(tiles, (void*)(0), (void*)(0));
 SQ_MEM_SetTiledPal8(tiles_pal);
 SQ_SetSpriteColMaps(colmaps);

 SQ_MAP_Init(0U, 0x5000U, 64U, 64U);
 SQ_MAP_MoveTo(0U, 0U);

// SQ_SetC0Location(0x1000U);
// SQ_SetBitmapC0Reload(1);
// SQ_SetTiledC0Reload(1);

 SQ_SetScreenSplit(200);

 SQ_Start();
}
