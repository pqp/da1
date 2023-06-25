include "hardware.inc"
include "charmap.inc"

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
	;call hUGE_dosound

	ld a, [rSCX]
	inc a
	ld [rSCX], a
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
	dec bc
	ld a, b
	or a, c
	ld a, [de]
	inc de
	jp nz, memset
	ret

OAM_Move:
	ld a, b
	ld [de], a
	inc de
	ld a, c
	ld [de], a
	ret

PrintString:
	ld a, [hli]
	ld [de], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, PrintString
	ret	

TransitionScene:
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

	; We can load data into VRAM now
	ld hl, carnival_ase
	ld bc, carnival_ase_end - carnival_ase
	ld de, $8800
	call memcpy

	; Load the same data into the Sprite Tiles Table
	;ld hl, tileset_scene1
	;ld bc, tileset_scene1_end - tileset_scene1
	;ld de, $8000
	;call memcpy

	ld hl, charset
	ld bc, charset_end - charset
	ld de, $9000
	call memcpy

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

	ld de, _HRAM
	ld bc, Run_DMA_end - Run_DMA
	ld hl, Run_DMA
	call memcpy

	; Clear BG map
	ld a, 0
	ld de, $9800
	ld bc, $9BFF - $9800
	call memset

	ld a, 0
	ld de, _OAMRAM
	ld bc, $FE9F - $FE00
	call memset

	ld de, $9800
	ld bc, 38
	ld hl, test_string
	call PrintString

	; initialize the palette
	ld a, %11100100
	ld [rBGP], a

	; Turn the LCD back on, and set addresses for tile data
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
	ld [rLCDC], a

	; Clear any pending interrupts
	ld a, 0
	ldh [rIF], a

	ei ; turn on interrupts

.loop
	jp .loop

Run_DMA:
	ld a, $C0
	ldh [$FF46], a
	ld a, 40
.wait
	dec a
	jr nz, .wait
	ret
Run_DMA_end:

SECTION "Data", ROM0[$2000]

test_string:
db "Hello. This is a test string. Goodbye!~"

sine_table:
; Generate a 256-byte sine table with values in the range [0, 128]
; (shifted and scaled from the range [-1.0, 1.0])
ANGLE = 0.0
    REPT 256
        db (MUL(64.0, SIN(ANGLE)) + 64.0) >> 16
ANGLE = ANGLE + 256.0 ; 256.0 = 65536 degrees / 256 entries
    ENDR
sine_table_end:

carnival_ase:
INCBIN "res/carnival_ase.2bpp"
carnival_ase_end:

charset:
INCBIN "res/charset.2bpp"
charset_end: