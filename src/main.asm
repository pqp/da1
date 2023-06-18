include "hardware.inc"

SECTION "Timer Interrupt", ROM0[$0050]

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

SECTION "Code", ROM0[$200]

TimerInterrupt:
	ld hl, $BEEF
	reti

; Basic memcpy
; Doesn't check for VBlank
memcpy:
	ld a, [hli]
	ld [de], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, memcpy
	ret

EntryPoint:
WaitForVBlank:
	; Wait until we're in the VBlank period (scanline 144)
	ld a, [rLY]
	cp 144
	jp nz, WaitForVBlank

	; Turn off the LCD
	ld a, [rLCDC]
	or a, LCDCF_OFF 
	ld [rLCDC], a

	; We can load data into VRAM now
	ld hl, tileset_scene1
	ld bc, tileset_scene1_end - tileset_scene1
	ld de, $9000
	call memcpy

	ld a, %00000101
	ld [rTAC], a

	ei ; turn on interrupts
	nop

	; Turn the LCD back on, and set addresses for tile data
	ld a, LCDCF_ON | LCDCF_BGON
	ld [rLCDC], a

	jr @

SECTION "Data", ROM0[$3000]

tileset_scene1:
INCBIN "res/tileset_scene1.2bpp"
tileset_scene1_end: