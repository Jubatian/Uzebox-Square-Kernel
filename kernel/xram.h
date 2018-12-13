/*
 *  SPI RAM basic interface functions
 *  Copyright (C) 2017 Sandor Zsuga (Jubatian)
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
*/



/*
**  Important: Before using the functions of this library, you have to
**  initialize the SD card (otherwise it will interfere with the SPI RAM, so
**  doing an SPI init is not sufficient!). The routines assume that the SPI
**  is set up for a data rate of 14MHz (maximal speed on the UzeBox).
*/



#ifndef XRAM_H
#define XRAM_H


#include <stdint.h>



/*
** Reads unsigned or signed 8 bit value from SPI RAM.
*/
uint8_t XRAM_ReadU8(uint8_t bank, uint16_t addr);
 int8_t XRAM_ReadS8(uint8_t bank, uint16_t addr);

/*
** Writes unsigned or signed 8 bit value to SPI RAM.
*/
void XRAM_WriteU8(uint8_t bank, uint16_t addr, uint8_t val);
void XRAM_WriteS8(uint8_t bank, uint16_t addr,  int8_t val);

/*
** Reads unsigned or signed 16 bit value from SPI RAM.
*/
uint16_t XRAM_ReadU16(uint8_t bank, uint16_t addr);
 int16_t XRAM_ReadS16(uint8_t bank, uint16_t addr);

/*
** Writes unsigned or signed 16 bit value to SPI RAM.
*/
void XRAM_WriteU16(uint8_t bank, uint16_t addr, uint16_t val);
void XRAM_WriteS16(uint8_t bank, uint16_t addr,  int16_t val);

/*
** Reads unsigned or signed 32 bit value from SPI RAM.
*/
uint32_t XRAM_ReadU32(uint8_t bank, uint16_t addr);
 int32_t XRAM_ReadS32(uint8_t bank, uint16_t addr);

/*
** Writes unsigned or signed 32 bit value to SPI RAM.
*/
void XRAM_WriteU32(uint8_t bank, uint16_t addr, uint32_t val);
void XRAM_WriteS32(uint8_t bank, uint16_t addr,  int32_t val);

/*
** Reads into RAM from SPI RAM.
*/
void XRAM_ReadInto(uint8_t bank, uint16_t addr, void* dst, uint16_t len);

/*
** Writes from RAM to SPI RAM.
*/
void XRAM_WriteFrom(uint8_t bank, uint16_t addr, void* src, uint16_t len);



/*
** Starts a sequential read from SPI RAM.
*/
void XRAM_SeqReadStart(uint8_t bank, uint16_t addr);

/*
** Sequentially reads unsigned or signed 8 bit value from SPI RAM.
*/
uint8_t XRAM_SeqReadU8(void);
 int8_t XRAM_SeqReadS8(void);

/*
** Sequentially reads unsigned or signed 16 bit value from SPI RAM.
*/
uint16_t XRAM_SeqReadU16(void);
 int16_t XRAM_SeqReadS16(void);

/*
** Sequentially reads unsigned or signed 32 bit value from SPI RAM.
*/
uint32_t XRAM_SeqReadU32(void);
 int32_t XRAM_SeqReadS32(void);

/*
** Sequentally reads into RAM from SPI RAM.
*/
void XRAM_SeqReadInto(void* dst, uint16_t len);

/*
** Terminates sequential SPI RAM read.
*/
void XRAM_SeqReadEnd(void);



/*
** Starts a sequential write to SPI RAM.
*/
void XRAM_SeqWriteStart(uint8_t bank, uint16_t addr);

/*
** Sequentially writes unsigned or signed 8 bit value to SPI RAM.
*/
void XRAM_SeqWriteU8(uint8_t val);
void XRAM_SeqWriteS8( int8_t val);

/*
** Sequentially writes unsigned or signed 16 bit value to SPI RAM.
*/
void XRAM_SeqWriteU16(uint16_t val);
void XRAM_SeqWriteS16( int16_t val);

/*
** Sequentially writes unsigned or signed 32 bit value to SPI RAM.
*/
void XRAM_SeqWriteU32(uint32_t val);
void XRAM_SeqWriteS32( int32_t val);

/*
** Sequentally writes from RAM to SPI RAM.
*/
void XRAM_SeqWriteFrom(void* src, uint16_t len);

/*
** Terminates sequential SPI RAM write.
*/
void XRAM_SeqWriteEnd(void);



#endif
