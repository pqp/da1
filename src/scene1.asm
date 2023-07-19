include "hardware.inc"
include "charmap.inc"
include "macros.inc"

SECTION "Scene 1", ROM0[$1200]

Scene1Init::
    di

	WriteAddress Scene1Loop, Loop
	WriteAddress Stat1, StatVector
	WriteAddress VBlank1, VBlankVector
	WriteAddress Timer1, TimerVector

.WaitUntilSafe:
    ; wait until LCD is safe to turn off
    ld a, [rSTAT]
    and STATF_LCD
    jp nz, .WaitUntilSafe

    ; turn off LCD
	ld a, LCDCF_OFF 
	ld [rLCDC], a

    ; load tile data into VRAM
    ld de, spiral1
    ld bc, spiral1_end - spiral1
    ld hl, $9000
    call memcpy

    ld de, spiral2
    ld bc, spiral2_end - spiral2
    ld hl, $8800
    call memcpy

	ld a, 20
	ld [TMP], a
    ld de, spiral_map
    ld bc, spiral_map_end - spiral_map
    ld hl, $9800
    call memcpy_scrn

    ; reset the palette
	ld a, %00011011
	ld [rBGP], a

	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
	ld [rLCDC], a
    
    reti

VBlank1:
    call hUGE_dosound
    reti

Stat1:
    reti

Timer1:
    reti

Scene1Loop:
    halt
    jp Scene1Loop