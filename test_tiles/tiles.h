#ifndef TILES_H
#define TILES_H

#include <sq_kernel.h>

extern const uint8_t tiles[4096] SQ_SECTION_TILESET;
extern const uint8_t tiles_pal[16] SQ_SECTION_CONST;
extern const uint8_t tiles_map[64 * 64] SQ_SECTION_CONST;

#endif
