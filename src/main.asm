include "hardware.inc"
include "charmap.inc"

DEF TMP EQU $C0B0
DEF VBlankVector EQU $C0B2
DEF StatVector EQU $C0B4
DEF TimerVector EQU $C0B6
DEF ScrollerX EQU $C0D0
DEF ScrollerSwapOn EQU $C120
DEF ScrollerStringOffset EQU $C130
DEF ScrollerNewChar EQU $C140
DEF TextLen EQU 49

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

WriteVector:
	ld a, l
	ld [de], a
	ld a, h
	inc de
	ld [de], a
	ret

VBlankInterrupt:
	ld a, [VBlankVector]
	ld l, a
	ld a, [VBlankVector+1]
	ld h, a
	jp hl

VBlank1:
	; Are we updating the text in VRAM?
	ld a, [ScrollerSwapOn]
	cp a, 1
	jp nz, .VBlankEnd ; if not, bounce

	ld hl, $9980 ; where the scroller is located in VRAM
.swap:
	inc hl  
	ld a, [hl] ; get next character tile
	dec hl
	ld [hl], a ; swap it with the previous character tile
	ld a, $94 
	cp a, l ; are we past the screen?
	jp z, .swappingDone ; if so, stop swapping
	inc hl ; otherwise, move to the next character and swap again
	jp .swap

.swappingDone:	
	; now that we're done exchanging tiles already visible on 
	; the screen, let's get the next character tile ready
	ld hl, $9994
	ld a, [ScrollerNewChar]  
	ld [hl], a ; write the next character just outside the visible area of the tilemap

	; this new character will eventually scroll into view

	ld a, [ScrollerStringOffset]
	inc a ; increment our position in the string, so we grab the next character in memory
	ld [ScrollerStringOffset], a

	; toggle the scroller swapping off until the region has scrolled another 8 pixels
	ld a, 0
	ld [ScrollerSwapOn], a

.VBlankEnd:
	call hUGE_dosound ; keep the song playing
	reti

StatInterrupt:
	ld a, [StatVector]
	ld l, a
	ld a, [StatVector+1]
	ld h, a
	jp hl

; this interrupt routine is run if we are at LY=95
; (where the scroller is)
Stat1:

	; scroll the text scroller region by a pixel
	ld a, [ScrollerX]
	inc a
	ld [ScrollerX], a
	ld [rSCX], a

	; has the scroller scrolled by 8 pixels?
	cp a, 8
	jp z, .swapCharacters ; if so, toggle character swapping on
	jp .setup ; otherwise, set up the STAT interrupt for the end of this region

.swapCharacters:
	ld a, 1
	ld [ScrollerSwapOn], a ; toggle scroller update in VBlank interrupt

	ld a, 0
	ld [ScrollerX], a ; clear scroll x-coord 

.setup:
	; the next interrupt routine will trigger when LY=104
	ld a, 104
	ld [rLYC], a

	ld de, StatVector
	ld hl, Stat2
	call WriteVector
	reti

Stat2:
	ld a, $00 ; don't scroll anything other than the text
	ld [rSCX], a

	; the previous interrupt routine will trigger when LY=95 again
	ld a, 95
	ld [rLYC], a

	ld de, StatVector
	ld hl, Stat1
	call WriteVector
	reti

TimerInterrupt:
	ld a, [TimerVector]
	ld l, a
	ld a, [TimerVector+1]
	ld h, a
	jp hl

	reti

Timer1:
	reti

; Basic, naive memcpy
memcpy:
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, memcpy
	ret

memcpy_scrn:
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
memset:
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

PrintString:
	ld a, e
	ld [TMP], a
	cp a, $94
	jp z, .done

	ld a, [hli]
	ld [de], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, PrintString
.done:
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

	call IntroInit

	; We can load data into VRAM now
	ld de, carnival_ase_1
	ld bc, carnival_ase_1_end - carnival_ase_1
	ld hl, $9000
	call memcpy

	ld de, carnival_ase_2
	ld bc, carnival_ase_2_end - carnival_ase_2
	ld hl, $8800
	call memcpy

	ld de, charset
	ld bc, charset_end - charset
	ld hl, $8B00
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

	; copy title screen tilemap into memory, taking screen specs into account
	ld a, 20
	ld [TMP], a
	ld hl, $9800
	ld bc, carnival_ase_tilemap_end - carnival_ase_tilemap
	ld de, carnival_ase_tilemap
	call memcpy_scrn

	; draw the test string
	ld de, $9980
	ld bc, TextLen
	ld hl, test_string
	call PrintString

	; initialize the palette
	ld a, %00011011
	ld [rBGP], a

	; write address of first stat interrupt routine to StatVector
	ld a, LOW(Stat1)
	ld [StatVector], a
	ld a, HIGH(Stat1)
	ld [StatVector+1], a

	ld a, LOW(VBlank1)
	ld [VBlankVector], a
	ld a, HIGH(VBlank1)
	ld [VBlankVector+1], a

	ld a, LOW(Timer1)
	ld [TimerVector], a
	ld a, HIGH(Timer1)
	ld [TimerVector+1], a

	ld a, 0
	ld [ScrollerX], a
	ld [ScrollerSwapOn], a

	; TODO: actually calculate the offset
	ld a, 21
	ld [ScrollerStringOffset], a

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

.loop:
	ld a, [ScrollerSwapOn]
	cp a, 1
	jp z, .swap
	jp .done

.swap:
	; get new character for scroller ready
	ld hl, test_string
	ld a, [ScrollerStringOffset]
	ld b, 0
	ld c, a
	add hl, bc
	ld a, [hl]
	cp a, 255
	jp z, .endOfString
	ld [ScrollerNewChar], a
	jp .done

.endOfString:
	ld a, 0
	ld [ScrollerStringOffset], a

.done:
	halt
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
db "Hello world. This is a test string. It is long. ~"

; swiped from the RGBDS docs
sine_table:
; Generate a 256-byte sine table with values in the range [0, 128]
; (shifted and scaled from the range [-1.0, 1.0])
ANGLE = 0.0
    REPT 256
        db (MUL(64.0, SIN(ANGLE)) + 64.0) >> 16
ANGLE = ANGLE + 256.0 ; 256.0 = 65536 degrees / 256 entries
    ENDR
sine_table_end:

carnival_ase_1:
INCBIN "res/carnival_ase.2bpp",0,2048
carnival_ase_1_end:

carnival_ase_2:
INCBIN "res/carnival_ase.2bpp",2048
carnival_ase_2_end:

/*
carnival_ase_palette:
INCBIN "res/carnival_ase.pal"
carnival_ase_palette_end:
*/

carnival_ase_tilemap:
INCBIN "res/carnival_ase.map"
carnival_ase_tilemap_end:

charset:
INCBIN "res/charset.2bpp",512
charset_end: