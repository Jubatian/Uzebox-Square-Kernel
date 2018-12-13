/*
 *  Uzebox Square Kernel - Video Mode 0, IT
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


;
; This file is included in the vector table, to provide vectors 14 (TIMER1
; Compare B) and above.
;


TIMER1_COMPB_vect:

	; IT at 1430, entry at 1433

	ldi   ZL,     0        ; (1434) 5 cycles wide (normal non-scrolling)
	out   PIXOUT, ZL
	jmp   sq_vm0_scanline  ; (1438)
