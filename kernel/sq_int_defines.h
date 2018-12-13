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


/*
** Internal defines to the U2 kernel, not meant to be used / included in games
*/


#include <avr/io.h>


/*
** For some reason the Atmega1284P io.h does not include the old "PA0" defines
*/

#ifndef PA0
#define PA0 PORTA0
#define PA1 PORTA1
#define PA2 PORTA2
#define PA3 PORTA3
#define PA4 PORTA4
#define PA5 PORTA5
#define PA6 PORTA6
#define PA7 PORTA7
#endif
#ifndef PB0
#define PB0 PORTB0
#define PB1 PORTB1
#define PB2 PORTB2
#define PB3 PORTB3
#define PB4 PORTB4
#define PB5 PORTB5
#define PB6 PORTB6
#define PB7 PORTB7
#endif
#ifndef PC0
#define PC0 PORTC0
#define PC1 PORTC1
#define PC2 PORTC2
#define PC3 PORTC3
#define PC4 PORTC4
#define PC5 PORTC5
#define PC6 PORTC6
#define PC7 PORTC7
#endif
#ifndef PD0
#define PD0 PORTD0
#define PD1 PORTD1
#define PD2 PORTD2
#define PD3 PORTD3
#define PD4 PORTD4
#define PD5 PORTD5
#define PD6 PORTD6
#define PD7 PORTD7
#endif


/*
** Various IO pins and ports
*/

#define SYNC_PIN         PB0
#define SYNC_PORT        PORTB
#define VIDEOCE_PIN      PB4

#define PIXOUT           _SFR_IO_ADDR(PORTC)

#define JOYPAD_OUT_PORT  PORTA
#define JOYPAD_IN_PORT   PINA
#define JOYPAD_CLOCK_PIN PA3
#define JOYPAD_LATCH_PIN PA2
#define JOYPAD_DATA1_PIN PA0
#define JOYPAD_DATA2_PIN PA1


/*
** EEPROM
*/

#define EEPROM_HEADER_VER   1
#define EEPROM_BLOCK_SIZE   32
#define EEPROM_HEADER_SIZE  1
#define EEPROM_SIGNATURE    0x555A
#define EEPROM_SIGNATURE2   0x555B
#define EEPROM_FREE_BLOCK   0xffff

#define EEPROM_ERROR_INVALID_BLOCK   0x1
#define EEPROM_ERROR_FULL            0x2
#define EEPROM_ERROR_BLOCK_NOT_FOUND 0x3
#define EEPROM_ERROR_NOT_FORMATTED   0x4
