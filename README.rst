
Uzebox Square Kernel
==============================================================================


:Author:   Sandor Zsuga (Jubatian)
:License:  GNU GPLv3 (Version 3 of the GNU General Public License)




Overview
------------------------------------------------------------------------------


This is a new, currently experimental kernel for the Uzebox open source game
console. It is not intended to be a replacement as a generic kernel, rather
serving a very specific purpose.

It is strongly tied with a specially designed SPI RAM using video mode to
exploit the strengths of the extended memory the chip provides, and also
keeping square pixels, making it easy to create and possibly port graphics.

Also a key goal is a plain C interface, making game development easier and
more portable in general.




How to start
------------------------------------------------------------------------------


Currently the easiest is to poke around in the examples provided. Check them
out, try to build them.

Note that you will need to copy a compiled binary of Packrom from the Uzebox
repository into a Packrom folder created in this repo (it is on .gitignore,
so it won't interfere with this repository).

For generating images, use the Uzebox branch of Insaniquant (one of my repos),
you will need to generate 16 color 232x200 images with it for the image
viewer.
