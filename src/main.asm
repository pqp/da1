include "hardware.inc"

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

SECTION "Code", ROM0[$200]

VBlankInterrupt:
	call hUGE_dosound
	reti

StatInterrupt:
	reti

TimerInterrupt:
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

; Set [de] to a for bc bytes
memset:
	ld [de], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, memset
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

	; Turn off the LCD
	ld a, LCDCF_OFF 
	ld [rLCDC], a
	
	ld hl, sample_song
	call hUGE_init

	; We can load data into VRAM now
	ld hl, tileset_scene1
	ld bc, tileset_scene1_end - tileset_scene1
	ld de, $9000
	call memcpy

	; Enable timer, VBlank, stat interrupts
	ld a, IEF_TIMER | IEF_VBLANK | IEF_STAT
	ld [rIE], a

	; Set timer control values
	ld a, TACF_START | TACF_4KHZ
	ld [rTAC], a

	ld a, STATF_LYC
	ld [rSTAT], a

	ld a, 72
	ld [rLYC], a

	; Enable audio, crank the volume
	ld a, AUDENA_ON
	ld [rAUDENA], a
	ld a, $FF
	ld [rAUDTERM], a
	ld a, $77
	ld [rAUDVOL], a

	; Clear BG map
	ld a, 0
	ld de, $9800
	ld bc, $9BFF - $9800
	;call memset

	; Turn the LCD back on, and set addresses for tile data
	ld a, LCDCF_ON | LCDCF_BGON
	ld [rLCDC], a

	ei ; turn on interrupts

.loop
	jp .loop

SECTION "Data", ROM0[$2000]

tileset_scene1:
INCBIN "res/tileset_scene1.2bpp"
tileset_scene1_end: