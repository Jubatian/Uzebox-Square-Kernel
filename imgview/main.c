#include <sq_kernel.h>
#include <string.h>



static uint16_t main_filectr = 0U;
static uint16_t main_p1btn_p = 0U;



/*
** Try to find the next file containing a 232x200 image.
** This is done by checking the size against these dimensions, so the first
** four bytes must be as follows: 232, 0, 200, 0. No error, just doesn't
** return at all if there is no such file. The SQ kernel filesystem structure
** is set up for reading the found file on return.
*/
static void find_next_image(void)
{
 uint16_t      cpos;
 sdc_struct_t  tmps;
 uint32_t      clus;
 sdc_struct_t* sqss;
 uint8_t*      sqbf;

 /* Prepare a work filesystem structure for reading the root directory */

 sqss = SQ_GetFSStruct();
 sqbf = sqss->bufp;
 memcpy(&tmps, sqss, sizeof(tmps));
 tmps.bufp = SQ_GetBlitterTilePtr(16);

 FS_Select_Root(&tmps);

 /* Skip root dir. entries until reaching current. */

 main_filectr ++;
 cpos = main_filectr;

 while (cpos >= 16U){
  cpos -= 16U;
  if (FS_Next_Sector(&tmps) != 0U){
   main_filectr = 0U;
   FS_Select_Root(&tmps);
   break;
  }
 }
 FS_Read_Sector(&tmps);

 /* Skim files until finding one where the first 4 bytes match */

 while (1){

  clus = FS_Get_File_Cluster(sqss, tmps.bufp + ((main_filectr & 0xFU) * 32U));
  if (clus != 0U){
   FS_Select_Cluster(sqss, clus);
   if (FS_Read_Sector(sqss) == 0U){
    if ( (sqbf[0] == 232U) &&
         (sqbf[1] ==   0U) &&
         (sqbf[2] == 200U) &&
         (sqbf[3] ==   0U) ){ /* A suitable image file is found, return */
     return;
    }
   }
  }

  /* No image file, keep going */

  main_filectr ++;
  if ((main_filectr & 0xFU) == 0U){
   if (FS_Next_Sector(&tmps) != 0U){
    main_filectr = 0U;
    FS_Select_Root(&tmps);
   }
   FS_Read_Sector(&tmps);
  }

 }
}



/*
** Finds and Displays next image
*/
static void display_next_image(void)
{
 find_next_image();
 SQ_LoadData(SQ_GetFSStruct(), 1U, 0U, 64U);
 SQ_PrepWideBitmap(0U, 0U, 1U, 2U + 2U + 16U);
 SQ_XRAM_SetBitmapPal8(1U, 2U + 2U);
}



/*
** Frame routine (called on the completion of a display frame)
*/
static void frame(void)
{
 uint16_t p1btn_p = main_p1btn_p;
 uint16_t p1btn_c = SQ_GetP1Buttons();

 main_p1btn_p = p1btn_c;

 if ( ((p1btn_p ^ p1btn_c) & (~p1btn_p)) != 0U){ /* Button press */

  display_next_image();

 }
}



int main(void)
{
 SQ_SetFrameFunc(&frame);
 SQ_SetWideBitmap();

 display_next_image();

 SQ_Start();
}
