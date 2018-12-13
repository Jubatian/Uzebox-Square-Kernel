#include <sq_kernel.h>
#include <string.h>



static uint16_t main_framectr = 0U;


static uint8_t const testimg1[8] SQ_SECTION_CONST = {
 0x18U,
 0x3CU,
 0x66U,
 0x66U,
 0x7EU,
 0x66U,
 0x66U,
 0x00U
};

static uint8_t const testimg2[16] SQ_SECTION_CONST = {
 0x01U, 0x40U,
 0x06U, 0x90U,
 0x1BU, 0xE4U,
 0x6FU, 0xF9U,
 0x6FU, 0xF9U,
 0x1BU, 0xE4U,
 0x06U, 0x90U,
 0x01U, 0x40U
};


void frame(void)
{
 uint8_t x;
 uint8_t y;

 main_framectr ++;

 x = (uint8_t)(SQ_Sin8(main_framectr >> 1)) + 128U;
 y = (uint8_t)(SQ_Cos8(main_framectr >> 1)) + 128U;

 if ((main_framectr & 0x7U) == 0U){
  SQ_MEM_BitmapBlit1(x, y, 8, 8, testimg1, (main_framectr >> 3) << 4);
 }

 if ((main_framectr & 0x7U) == 4U){
  SQ_MEM_BitmapBlit2(x + 10U, y + 10U, 8, 8, testimg2, 0x4560U);
 }

 if (!SQ_IsBitmapOpScheduled()){
  SQ_XRAM_BitmapCopySched(104U, 100U, 232U, 80U, 1U, 2U + 2U + 16U);
 }

}



int main(void)
{
 uint32_t cluster;

 cluster = FS_Find(SQ_GetFSStruct(),
                   FS_FIND_NAME('R','I','D','E','R','S',' ',' ','D','A','T'));

 if (cluster != 0U){
  FS_Select_Cluster(SQ_GetFSStruct(), cluster);
  SQ_LoadData(SQ_GetFSStruct(), 1U, 0U, 64U);
  SQ_PrepWideBitmap(0U, 0U, 1U, 2U + 2U + 16U);
  SQ_XRAM_SetBitmapPal8(1U, 2U + 2U);
 }

 SQ_SetFrameFunc(&frame);

 SQ_SetWideBitmap();

 SQ_Start();
}
