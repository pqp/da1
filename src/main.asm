include "hardware.inc"
include "charmap.inc"

DEF Loop EQU $C0B0
DEF VBlankVector EQU $C0B2
DEF StatVector EQU $C0B4
DEF TimerVector EQU $C0B6
DEF TMP EQU $C0C0

EXPORT Loop, VBlankVector, StatVector, TimerVector, TMP

SECTION "VBlank Interrupt Vector", ROM0[$0040]
	
	jp VBlankInterrupt

SECTION "Stat Interrupt Vector", ROM0[$0048]

	jp StatInterrupt

SECTION "Timer Interrupt Vector", ROM0[$0050]

	jp TimerInterrupt

SECTION "Header", ROM0[$100]

	; This is your ROM's entry point
	; You have 4 bytes of code to do... something
	di
	jp EntryPoint

	; Make sure to allocate some space for the header, so no important
	; code gets put there and later overwritten by RGBFIX.
	; RGBFIX is designed to operate over a zero-filled header, so make
	; sure to put zeros regardless of the padding value. (This feature
	; was introduced in RGBDS 0.4.0, but the -MG etc flags were also
	; introduced in that version.)
	ds $150 - @, 0

SECTION "Main", ROM0[$200]

VBlankInterrupt:
	di

	ld a, [VBlankVector]
	ld l, a
	ld a, [VBlankVector+1]
	ld h, a
	jp hl

StatInterrupt:
	di

	ld a, [StatVector]
	ld l, a
	ld a, [StatVector+1]
	ld h, a
	jp hl

TimerInterrupt:
	di

	ld a, [TimerVector]
	ld l, a
	ld a, [TimerVector+1]
	ld h, a
	jp hl

	reti

TransitionVBlank:
	call hUGE_dosound	
	reti

; Basic, naive memcpy
memcpy::
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, memcpy
	ret

memcpy_scrn::
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	; test total byte count
	ld a, b
	or a, c
	jp z, .done
	; Decrement x-coord
	ld a, [TMP]
	dec a
	ld [TMP], a
	; Are we past x-coord 19?
	cp a, 0
	jp nz, memcpy_scrn
.reset:
	ld a, b
	ld [TMP], a
	ld a, c
	ld [TMP+1], a

	; add $20 to destination address (so it skips to the next row)
	ld bc, 12 
	add hl, bc

	; load total byte count into BC
	ld a, [TMP]
	ld b, a
	ld a, [TMP+1]
	ld c, a
	; reset local byte count to 19
	ld a, 20
	ld [TMP], a
	jp memcpy_scrn
.done:
	ret

; Set [hl] to a for bc bytes
memset::
	ld [hli], a
	ld d, a
	dec bc
	ld a, b
	or a, c
	ld a, d
	jp nz, memset
	ret

OAM_Move:
	ld a, b
	ld [de], a
	inc de
	ld a, c
	ld [de], a
	ret

EntryPoint:
	; Disable audio
	ld a, AUDENA_OFF
	ld [rAUDENA], a

WaitForVBlank:
	; Wait until we're in the VBlank period (scanline 144)
	ld a, [rLY]
	cp 144
	jp nz, WaitForVBlank

Init:
	; Turn off the LCD
	ld a, LCDCF_OFF 
	ld [rLCDC], a
	
	; Load song into hUGEDriver
	ld hl, sample_song
	call hUGE_init

	; Enable timer, VBlank, stat interrupts
	ld a, IEF_TIMER | IEF_VBLANK | IEF_STAT
	ld [rIE], a

	; Set timer control values
	ld a, TACF_START | TACF_4KHZ
	ld [rTAC], a

	; Enable audio, crank the volume
	ld a, AUDENA_ON
	ld [rAUDENA], a
	ld a, $FF
	ld [rAUDTERM], a
	ld a, $77
	ld [rAUDVOL], a

	; Copy OAM DMA copying routine into HRAM
	ld hl, _HRAM
	ld bc, Run_DMA_end - Run_DMA
	ld de, Run_DMA
	call memcpy

	; Clear BG map
	ld a, 0
	ld hl, $9800
	ld bc, $9BFF - $9800
	call memset

	; Clear OAM
	ld a, 0
	ld hl, _OAMRAM
	ld bc, $FE9F - $FE00
	call memset

	; initialize the palette
	ld a, %00011011
	ld [rBGP], a

	call IntroInit

	; Turn the LCD back on, and set addresses for tile data
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
	ld [rLCDC], a

	; enable LYC=LY STAT interrupt source and LYC=LY flag
	ld a, STATF_LYC | STATF_LYCF
	ld [rSTAT], a

	ld a, 95
	ld [rLYC], a

	; Clear any pending interrupts
	ld a, 0
	ldh [rIF], a

	ei ; turn on interrupts

MainLoop::
	ld a, [Loop]
	ld l, a
	ld a, [Loop+1]
	ld h, a
	jp hl

Run_DMA:
	ld a, $C0
	ldh [$FF46], a
	ld a, 40
.wait
	dec a
	jr nz, .wait
	ret
Run_DMA_end: