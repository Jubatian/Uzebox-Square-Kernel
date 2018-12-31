
Uzebox Square Kernel Reference Manual
==============================================================================


:Author:   Sandor Zsuga (Jubatian)
:License:  GNU GPLv3 (Version 3 of the GNU General Public License)





Setting up a project
------------------------------------------------------------------------------



Makefile
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When building a game for the Uzebox using the Square Kernel, it is recommended
to start out from one of the simple example projects to get a basic Makefile.

Within the Makefile, regarding the kernel the following elements have
particular significance:

- The kernel is assembly code, so keep the ASMFLAGS definition for it.
- It needs its customized linker script, so make sure you don't remove it from
  the linker flags (LDFLAGS).
- Only one source file needs to be compiled to get the kernel's complete
  object file for linking: sq_kernel.s. Make sure to keep it.
- Have the kernel's directory in the include search path (INCLUDES) so
  including sq_kernel.h in your game works.

Other elements are not significant for the proper operation of the kernel, so
you may adapt them to your needs. Alternatively by taking these into your own
preferred Makefile layout should also work.



Includes
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

You need to include only one file to access every feature of the kernel: ::

    #include <sq_kernel.h>

Note that you do NOT need to include any AVR specific header. Using this
kernel using anything AVR specific may be easily avoided, keeping the
possibility of porting your game to different architectures more open if you
desired so.



Basic structure
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A simple game using this kernel may have code looking something like this: ::

    #include <sq_kernel.h>

    void frame(void)
    {
     /* Called every video frame, do game stuff here */
    }

    int main(void)
    {
     /* Load data if you need to, set up palette etc. */

     SQ_SetFrameFunc(&frame); /* Set frame() to be called every video frame */

     SQ_Start(); /* Start game */
    }

Video frames occur at a fixed 60Hz rate (as Uzebox generates NTSC timing), so
the callback mechanism this kernel employs also ensures proper timing.





Basic conventions, features and tasks
------------------------------------------------------------------------------



Kernel components
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The kernel is made up of three components which have different prefixes as
follows:

- SQ: The Square Kernel itself
- FS: The Filesystem support
- XRAM: The SPI RAM

The Filesystem support also has some low-level soutines prefixed SPI and SDC
which shouldn't be accessed when using this kernel. They are left there as the
component is the Bootloader Library within the original Uzebox kernel.

Identifier names not having either of these prefixes should be generally free
to use by the game.



Setting up and accessing data
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you need some constant game data, you should declare it like follows: ::

    const uint8_t data[] SQ_SECTION_CONST = { /* elements */ };

This puts it in the program memory of the Uzebox, so keeping the precious
internal RAM clear of it.

You must however access it by one of the Square Kernel functions having "MEM"
in their name. There are functions (optimized to inline) for simple reading,
but some more complex kernel functions like setting up a palette can also work
with such constant data.

Note: "MEM" functions are also ideal in case you had no means to know whether
the particular pointer you wanted to dereference pointed to such constant
data.



Available RAM and getting more RAM
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

There are 416 bytes of RAM (on the ATmega) available for user data, which can
be occupied by C variables and structures. This limit is enforced by the
linker script, so if you exceed it, you will face a compilation error.

It is however possible to have access to more RAM if you needed it by
utilizing areas normally reserved for the video display, which could be
particularly useful when loading and preparing data.

The function: ::

    void* SQ_GetBlitterTilePtr(uint8_t tno);

This gives you a pointer to the beginning of the data area of a "blitter
tile", a 32 byte block normally representing a work tile for the sprite
blitter. There are 100 such tile positions (0 - 99) laid out in a contiguous
manner.

Availability:

- Display OFF: All of it is free to use (up to 3200 bytes). Display OFF here
  means that you would reinitialize the display before returning from the
  video frame callback.

- Tiles & Sprites mode: By default blitter tiles 0-1 are free to use. By
  reducing the count of tiles the sprite blitter can use (85 by default), you
  can free up more. See SQ_SetMaxSpriteTiles().

- 200 pixels wide bitmap: All of it is free to use (up to 3200 bytes). This is
  what allows split-screen between this mode and the Tiles & Sprites mode.

- 232 pixels wide bitmap: Fully used.



The stack
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

There are 126 bytes of stack available for the user program, a bit limited,
but should be okay for normal use-cases.

The kernel implements a stack guard feature which is capable to detect when
this stack is overran. This case it will halt the game with the following
results:

- Screen turns blank.

- The User LED blinks at 30Hz rate (might be difficult to see, this rate was
  available without needing any storage for a counter to get a divider).

- Ports 0x39 and 0x3A get the values 0xDE and 0xAD. These ports are unused on
  the ATmega, emulators display their contents for debugging.





Kernel control
------------------------------------------------------------------------------


The following functions control the core operation of the kernel.



SQ_ClearFrameSkipped
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_ClearFrameSkipped(void);

Clears the Video frame was skipped flag. Use it to make it ready to catch a
subsequent skip.



SQ_IsFrameSkipped
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    uint8_t SQ_IsFrameSkipped(void);

Checks whether a Video frame was skipped since the start of the Video frame
callback or the last clearing of the flag.

This can be useful if you wanted to maintain timing during a task where you
are expecting to skip frames, an example could be keeping a music player
running while you were attempting to load data off from the filesystem.



SQ_Reset
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_Reset(void);

Executes a Soft Reset. This depending on the configuration of the Game
Selector (bootloader) may result in either landing back in the Game Selector
or restarting the game.



SQ_SetFrameFunc
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetFrameFunc(void (*fptr)(void));

Sets up the video frame callback. You must do this before SQ_Start(), later
you may change the video frame callback any time you wish.

The Video frame callback is (normally) called on every Vertical Blanking, 60
times a second, this function is where you can execute your game code. This
function takes no parameters (void) and returns void.



SQ_Start
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_Start(void);

Call this at the end of main() to start up the kernel.



SQ_VideoEnable
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_VideoEnable(void);

Enables cutting off by the next Video frame.

Normally the frame function runs until completion regardless of whether a new
video frame would be necessary to be started. The consequence is a flickering
screen if the frame function takes too long to execute, due to the missed
frames.

This is useful if you want to prepare data, a next section of the game
requiring some filesystem access and moving around stuff, however a problem
within an actual game scene.

Calling this function can eliminate this by allowing the kernel to cut off
your frame function, skipping the rest of it to keep the display going.

The recommended way of using it is putting your graphics rendering (without
any code which would affect your game state) at the end of your frame routine,
and calling SQ_VideoEnable() before starting to do it. The result is that if
you asked too much, some of it will be skipped, so instead of missing a frame,
you may momentarily miss only some fragments of some sprites (or whatever you
were drawing).





Video - general concepts
------------------------------------------------------------------------------


The Square Kernel provides two screen setups as follows:

- A 200x200 surface arbitrarily split between a Tiles & Sprites region on the
  top and a Bitmap region on the bottom (either may be absent).

- A 232x200 Bitmap mode.

Each of these modes have square pixels, and use 4 bits per pixel color depth.
Bitmap mode and Tiled mode has its own 16 color palette, and optionally it is
also possible to provide a new Color 0 on each scanline using an array.

The screen in 200x200 mode: ::

       |<------------- 200 pixels ------------->|
       |                                        |
    ---+----------------------------------------+
    A  | Blank                                  | ScreenShrink (0 - 99)
    |  +----------------------------------------+
    |  |                                        |
       | Tiles & Sprites region                 |
    2  |                                        |
    0  |                                        |
    0  |                                        |
       |                                        |
    l  |                                        |
    i  |                                        |
    n  +----------------------------------------+ ScreenSplit (0 - 200)
    e  |                                        |
    s  | Bitmap (200px wide) region             |
       |                                        |
    |  |                                        |
    |  +----------------------------------------+
    V  | Blank                                  | ScreenShrink (0 - 99)
    ---+----------------------------------------+

In 232x200 Bitmap mode the layout is similar except for that there is no split
point: the whole screen is Bitmap like if ScreenSplit was set zero.



SQ_SetScreenShrink
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetScreenShrink(uint8_t shrink);

Sets the amount of pixels to shrink the screen by. This many pixels are then
taken away from both the top and the bottom of the visible area.

By default this shrink amount is zero, so actual display is 200 lines tall.

Using screen shrinking creates more Vertical Blanking time in which the video
frame function (containing the game code) is allowed to run, so in some cases
it may be an useful trade-off to settle for a shorter screen to allow more
graphics rendering.



SQ_SetScreenSplit
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetScreenSplit(uint8_t split);

Sets the split point between the Tiles & Sprites region and the Bitmap region.

By default this is zero, so the whole screen would be Bitmap. Setting it to
200 or anything above makes the Tiles & Sprites region occupying the whole
screen.

If the screen is in 232x200 Bitmap mode when calling this, it leaves 232x200
Bitmap mode.



SQ_SetWideBitmap
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetWideBitmap(void);

Sets 232x200 Bitmap mode.





Video - colors and palette manipulation
------------------------------------------------------------------------------


One pixel is encoded in 4 bits, so its possible values may be represented by
the numbers 0 - 15. To map these numbers to visible colors, palettes are used,
defining which Uzebox color should be shown for each of the 16 pixel values.

Two distinct palettes are used:

- Tiles & Sprites region palette.

- Bitmap region palette.

So when using a split screen layout, you can define different color sets for
these two regions.

Also there is support for setting the color for pixel value 0 on each line by
an array, this feature is called Color 0 Reloading. Note that the color at
position 0 in the palette is not replaced when using it, Color 0 Reloading
only overrides it.



SQ_MEM_SetBitmapPal8
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_MEM_SetBitmapPal8(uint8_t const* ptr);

Sets Bitmap palette (both for 200px and 232px wide bitmaps) from internal
memory (RAM or Flash) source. The source must be 16 bytes long containing 16
colors, one for each pixel value.



SQ_MEM_SetTiledPal8
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_MEM_SetTiledPal8(uint8_t const* ptr);

Sets Tiles & Sprites region palette from internal memory (RAM or Flash)
source. The source must be 16 bytes long containing 16 colors, one for each
pixel value.



SQ_SetBitmapC0Reload
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetBitmapC0Reload(uint8_t ena);

Sets whether Color 0 Reloading should be used in Bitmap region (applies both
for 200px and 232px wide bitmaps). Nonzero for the "ena" parameter turns the
feature on.



SQ_SetC0Location
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetC0Location(uint8_t const* ramptr);

Sets the address of the Color 0 Reload table. This array must be in RAM, and
normally should take 200 bytes to specify a new color for each line. A smaller
array might be used if the actual region where Color 0 Reloading is enabled is
shorter (such as by shrinking the screen or only applying it on the Tiles &
Sprites region of a split-screen setup).



SQ_SetTiledC0Reload
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetTiledC0Reload(uint8_t ena);

Sets whether Color 0 Reloading should be used in Tiles & Sprites region.
Nonzero for the "ena" parameter turns the feature on.



SQ_SetBitmapColor8
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetBitmapColor8(uint8_t idx, uint8_t val);

Sets a single color in the Bitmap (200px or 232px wide) palette.



SQ_SetTiledColor8
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetTiledColor8(uint8_t idx, uint8_t val);

Sets a single color in the Tiles & Sprites region palette.



SQ_XRAM_SetBitmapPal8
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_XRAM_SetBitmapPal8(uint8_t srcbank, uint16_t srcoff);

Sets Bitmap palette (both for 200px and 232px wide bitmaps) from external
memory (SPI RAM) source. The source must be 16 bytes long containing 16
colors, one for each pixel value.



SQ_XRAM_SetTiledPal8
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_XRAM_SetTiledPal8(uint8_t srcbank, uint16_t srcoff);

Sets Tiles & Sprites region palette from external memory (SPI RAM) source. The
source must be 16 bytes long containing 16 colors, one for each pixel value.





Video - Bitmap mode
------------------------------------------------------------------------------


The Bitmap modes work with bitmap data: rectangular images in the external
memory (SPI RAM) defining every 4 bit pixel.

Images are stored horizontal left to right, then vertical top to bottom order,
high nybbles of bytes corresponding to the leftmost pixels. For example a 8x8
pixel image of a letter 'P' could look like this: ::

    uint8_t const img_letter_p[32] SECTION_CONST = {
     0x11, 0x11, 0x11, 0x00,
     0x11, 0x00, 0x01, 0x10,
     0x11, 0x00, 0x01, 0x10,
     0x11, 0x11, 0x11, 0x00,
     0x11, 0x00, 0x00, 0x00,
     0x11, 0x00, 0x00, 0x00,
     0x11, 0x00, 0x00, 0x00,
     0x00, 0x00, 0x00, 0x00
    };

Note that the Tiles & Sprites mode's tile and sprite images also use this
layout for their fixed 8x8 pixels size tiles.

Keep in mind that this format is that of the image sources which the bitmap
mode functions can take. The actual surface has a different layout, specific
to the way the hardware has to be worked with to make displaying these images
possible. So you absolutely shouldn't read and write the actual surface
directly.

The 200 pixels wide format takes 100 external memory bytes for each line, it
is possible to vertically scroll it if desired by advancing the Bitmap
Location by 100 bytes per line on an appropriately prepared tall bitmap.

The 232 pixels wide format is fixed at its 232x200 pixels size due to its
special layout interleaving RAM data to achieve this greater width. It is not
possible to scroll it.

There are functions provided for blitting 1bpp and 2bpp transparent images
onto the bitmap surface (pixel value 0 being transparent). They can be useful
for example to generate text. The layout of the data is demonstrated with the
letter 'P' from above: ::

    uint8_t const img_letter_p_1bpp[8] SECTION_CONST = {
     0xFC,
     0xC6,
     0xC6,
     0xFC,
     0xC0,
     0xC0,
     0xC0,
     0x00
    };
    uint8_t const img_letter_p_2bpp[16] SECTION_CONST = {
     0x55, 0x50,
     0x50, 0x14,
     0x50, 0x14,
     0x55, 0x50,
     0x50, 0x00,
     0x50, 0x00,
     0x50, 0x00,
     0x00, 0x00
    };



SQ_SetBitmapLocation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_SetBitmapLocation(uint8_t xrambank, uint16_t xramoff);

Sets the external memory (SPI RAM) location where the bitmap surface should
be placed. By default it is at offset zero in bank zero.

The bitmap surface for 200 pixels height takes 20000 external memory bytes
regardless of the mode. In 232 pixels wide mode, RAM is used to provide
additional width.

In 200 pixels wide mode you may use this function for vertical scrolling or
relocating the surface to other prepared image data.



SQ_PrepBitmap
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_PrepBitmap(uint8_t srcbank, uint16_t srcoff,
                       uint16_t rowcnt, void* workram);

Prepares a 200 pixels wide bitmap from the provided 200 pixels wide source.
The row count is arbitrary. The work RAM must be pointed to a 100 byte RAM
buffer which will be used for the conversion.

Note that you must not use this function if you want to set up a 232 pixels
wide bitmap, use SQ_PrepWideBitmap() then.



SQ_PrepBitmapTo
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_PrepBitmapTo(uint8_t dstbank, uint16_t dstoff,
                         uint8_t srcbank, uint16_t srcoff,
                         uint16_t rowcnt, void* workram);

Prepares a 200 pixels wide bitmap to a specified target area. You may use this
if you want to prepare multiple distinct images between which you would like
to change later, otherwise see SQ_PrepBitmap().



SQ_PrepWideBitmap
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_PrepWideBitmap(uint8_t srcbank, uint16_t srcoff);

Prepares a 232 pixels wide bitmap from the provided 232 pixels wide source.
The height is always 200 pixels.

Note that you must not use this function if you want to set up a 200 pixels
wide bitmap, use SQ_PrepBitmap() then.



SQ_MEM_BitmapBlit1
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_MEM_BitmapBlit1(uint8_t xpos, uint8_t ypos,
                            uint8_t width, uint8_t height,
                            uint8_t const* ptr, uint16_t colmap);

Transparent blits a 1bpp bitmap onto the displaying bitmap (200 or 232 pixels
wide). The source may be in RAM or in the ATmega's Flash.

The colmap parameter specifies color mapping as follows:

- bits  0- 3: Unused ('0' pixels are transparent)
- bits  4- 7: 4bpp color value for '1' pixels.
- bits  8-15: Unused

Width can be arbitrary, in the source it is rounded up to the next multiple of
8 to maintain proper byte boundaries.

Clipping is done to the displaying bitmap's width and 200 pixels height.



SQ_MEM_BitmapBlit2
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_MEM_BitmapBlit2(uint8_t xpos, uint8_t ypos,
                            uint8_t width, uint8_t height,
                            uint8_t const* ptr, uint16_t colmap);

Transparent blits a 2bpp bitmap onto the displaying bitmap (200 or 232 pixels
wide). The source may be in RAM or in the ATmega's Flash.

The colmap parameter specifies color mapping as follows:

- bits  0- 3: Unused ('0' pixels are transparent)
- bits  4- 7: 4bpp color value for '1' pixels.
- bits  8-11: 4bpp color value for '2' pixels.
- bits 12-15: 4bpp color value for '3' pixels.

Width can be arbitrary, in the source it is rounded up to the next multiple of
4 to maintain proper byte boundaries.

Clipping is done to the displaying bitmap's width and 200 pixels height.



SQ_XRAM_BitmapCopy
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_XRAM_BitmapCopy(uint8_t xpos, uint8_t ypos,
                            uint8_t width, uint8_t height,
                            uint8_t srcbank, uint16_t srcoff);

Block copies a 4bpp bitmap in the external memory (SPI RAM) onto the
displaying bitmap. No transparency, the X position and width is limited to
multiples of 8.

Clipping is done to the displaying bitmap's width and 200 pixels height.





Video - Bitmap mode scheduled operations
------------------------------------------------------------------------------


The scheduled bitmap operations allow for using spare vertical blanking time
to perform low priority bitmap operations.

Spare vertical blanking time occurs when the video frame routine (with the
game logic code) finishes before the next frame is required to start.

This feature is useful for example for implementing status displays on a strip
of bitmap mode for a Tiles & Sprites mode game, so the status keeps updating
without adversely affecting game performance.

Also it can carry out larger updates than possible in one frame by the direct
functions, which may make this useful for building the mechanics of title
screens and simple cutscenes.

When calling a scheduled operation, it won't start, rather only gets scheduled
for completion in spare vertical blanking time. The first time you may see it
completed is the next frame.



SQ_IsBitmapOpScheduled
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    uint8_t SQ_IsBitmapOpScheduled(void);

Checks whether there is a bitmap operation scheduled to complete in spare
vertical blanking time still in progress.



SQ_MEM_BitmapBlit1Sched
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_MEM_BitmapBlit1Sched(uint8_t xpos, uint8_t ypos,
                                 uint8_t width, uint8_t height,
                                 uint8_t const* ptr, uint16_t colmap);

Scheduled variant of SQ_MEM_BitmapBlit1().



SQ_MEM_BitmapBlit2Sched
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_MEM_BitmapBlit2Sched(uint8_t xpos, uint8_t ypos,
                                 uint8_t width, uint8_t height,
                                 uint8_t const* ptr, uint16_t colmap);

Scheduled variant of SQ_MEM_BitmapBlit2().



SQ_XRAM_BitmapCopySched
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Declaration: ::

    void SQ_XRAM_BitmapCopySched(uint8_t xpos, uint8_t ypos,
                                 uint8_t width, uint8_t height,
                                 uint8_t srcbank, uint16_t srcoff);

Scheduled variant of SQ_XRAM_BitmapCopy().
