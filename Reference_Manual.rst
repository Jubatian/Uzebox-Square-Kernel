
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

- Sprites & Tiles mode: By default blitter tiles 0-1 are free to use. By
  reducing the count of tiles the sprite blitter can use (85 by default), you
  can free up more. See SQ_SetMaxSpriteTiles().

- 200 pixels wide bitmap: All of it is free to use (up to 3200 bytes). This is
  what allows split-screen between this mode and the Sprites & Tiles mode.

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



void SQ_ClearFrameSkipped(void);
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Clears the Video frame was skipped flag. Use it to make it ready to catch a
subsequent skip.



uint8_t SQ_IsFrameSkipped(void);
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Checks whether a Video frame was skipped since the start of the Video frame
callback or the last clearing of the flag.

This can be useful if you wanted to maintain timing during a task where you
are expecting to skip frames, an example could be keeping a music player
running while you were attempting to load data off from the filesystem.



void SQ_Reset(void);
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Executes a Soft Reset. This depending on the configuration of the Game
Selector (bootloader) may result in either landing back in the Game Selector
or restarting the game.



void SQ_SetFrameFunc(void (*fptr)(void));
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Sets up the video frame callback. You must do this before SQ_Start(), later
you may change the video frame callback any time you wish.

The Video frame callback is (normally) called on every Vertical Blanking, 60
times a second, this function is where you can execute your game code. This
function takes no parameters (void) and returns void.



void SQ_Start(void);
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Call this at the end of main() to start up the kernel.



void SQ_VideoEnable(void);
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

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





Video - general functions
------------------------------------------------------------------------------
