include "hardware.inc"
include "charmap.inc"
include "macros.inc"

DEF ScrollerX EQU $C0D0
DEF ScrollerSwapOn EQU $C120
DEF ScrollerStringIndex EQU $C130
DEF ScrollerNewChar EQU $C140
DEF TimerCounter EQU $C200

SECTION "Intro", ROM0[$1000]

IntroInit::
	ld a, 0
	ld [TimerCounter], a

	; We can load data into VRAM now
	ld de, carnival_ase_1
	ld bc, carnival_ase_1_end - carnival_ase_1
	ld hl, $9000
	call memcpy

	ld de, carnival_ase_2
	ld bc, carnival_ase_2_end - carnival_ase_2
	ld hl, $8800
	call memcpy

	; keep the value of HL and write the charset right after the last tileset
	ld de, charset
	ld bc, charset_end - charset
	call memcpy

	; copy title screen tilemap into memory, taking screen specs into account
	ld a, 20
	ld [TMP], a
	ld hl, $9800
	ld bc, carnival_ase_tilemap_end - carnival_ase_tilemap
	ld de, carnival_ase_tilemap
	call memcpy_scrn

	; Write vectors for loop, and stat, vblank, and timer interrupts
	WriteAddress IntroLoop, Loop
	WriteAddress Stat1, StatVector
	WriteAddress VBlank1, VBlankVector
	WriteAddress Timer1, TimerVector

	ld a, 0
	ld [ScrollerX], a
	ld [ScrollerSwapOn], a

	ld a, SCRN_X_B + 1 ; width of screen in tiles + 1
	ld [ScrollerStringIndex], a

	; draw the test string
	ld de, $9980
	ld bc, intro_string_len
	ld hl, intro_string
	call PrintString
    ret

PrintString:
	ld a, e
	ld [TMP], a
	cp a, $95
	jp z, .done

	ld a, [hli]
	ld [de], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, PrintString
.done:

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

	ld a, [ScrollerStringIndex]
	inc a ; increment our position in the string, so we grab the next character in memory
	ld [ScrollerStringIndex], a

	; toggle the scroller swapping off until the region has scrolled another 8 pixels
	ld a, 0
	ld [ScrollerSwapOn], a

.VBlankEnd:
	call hUGE_dosound ; keep the song playing
	reti

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
	WriteVector
	reti

Stat2:
	ld a, $00 ; don't scroll anything other than the text
	ld [rSCX], a

	; the previous interrupt routine will trigger when LY=95 again
	ld a, 95
	ld [rLYC], a

	ld de, StatVector
	ld hl, Stat1
	WriteVector
	reti

Timer1:
	ld a, [TimerCounter]
	inc a
	ld [TimerCounter], a

	cp 255
	jp z, TransitionScene
	reti

TransitionScene:
	; change palette to black
	; wait for vblank
	; load new vram things
	ld a, %00000000
	ld [rBGP], a

	call Scene1Init
	reti

IntroLoop:
    ld a, [ScrollerSwapOn]
	cp a, 1
	jp z, .swap
	jp .done

.swap:
	; get new character for scroller ready
	ld hl, intro_string
	ld a, [ScrollerStringIndex]
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
	ld [ScrollerStringIndex], a

.done:
	halt
	jp IntroLoop