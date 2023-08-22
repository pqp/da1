include "hardware.inc"
include "charmap.inc"
include "macros.inc"

DEF TransitionDone EQU $C0C2
DEF TransitionSpiral1BytesLeft EQU $C0C4
DEF TransitionSpiral2BytesLeft EQU $C0C6
DEF TransitionSpiralMapBytesLeft EQU $C0C8
DEF Spiral1Loaded EQU $C0CA
DEF Spiral2Loaded EQU $C0CB
DEF SpiralMapLoaded EQU $C0CC
DEF TempSrcAddress EQU $C0D0
DEF TempDestAddress EQU $C0E0
DEF DataLoaded EQU $C0F0

DEF TILE_BYTES_PER_VBLANK EQU 32
DEF MAP_BYTES_PER_VBLANK EQU 16

SECTION "Scene 1", ROM0[$1200]

LoadingMemCpy:
    ; check byte count's most significant byte
    ld a, b
    cp a, 0 ; is it 0?
    jp z, .checkLeast ; if so, check the least significant byte
    jp .init ; otherwise, continue as usual

.checkLeast:
    ld a, c
    cp a, TILE_BYTES_PER_VBLANK
    jp nz, .init ; if the value left is greater than 16, continue as usual
    ld a, 1 ; otherwise, indicate that this is the last byte for this chunk of data
    ld [DataLoaded], a

.init:
    ld a, TILE_BYTES_PER_VBLANK
    ld [TMP], a

    ld a, [TempSrcAddress]
    ld e, a
    ld a, [TempSrcAddress+1]
    ld d, a

    ld a, [TempDestAddress]
    ld l, a
    ld a, [TempDestAddress+1]
    ld h, a

.loop:
    ld a, [de]
    ld [hli], a 
    inc de
    ld a, [TMP] ; load buffer byte count
    dec bc ; decrement total byte count
    dec a ; decrement buffer byte count
    ld [TMP], a ; write buffer byte count

    cp a, 0 ; are we done iterating through BYTES_PER_VBLANK bytes?
    jp nz, .loop ; if not, reiterate

    WriteTempSrcAddress  
    WriteTempDestAddress

    ret

LoadingMemCpyScrn:
    ; check byte count's most significant byte
    ld a, b
    cp a, 0 ; is it 0?
    jp z, .checkLeast ; if so, check the least significant byte
    jp .init ; otherwise, continue as usual

.checkLeast:
    ld a, c
    cp a, MAP_BYTES_PER_VBLANK
    jp nz, .init ; if the value left is greater than 16, continue as usual
    ld a, 1 ; otherwise, indicate that this is the last byte for this chunk of data
    ld [DataLoaded], a

.init:
    ld a, MAP_BYTES_PER_VBLANK
    ld [TMP], a

    ld a, [TempSrcAddress]
    ld e, a
    ld a, [TempSrcAddress+1]
    ld d, a

    ld a, [TempDestAddress]
    ld l, a
    ld a, [TempDestAddress+1]
    ld h, a

.loop:
    ld a, [de]
    ld [hli], a 
    inc de
    ld a, [TMP] ; load buffer byte count
    dec bc ; decrement total byte count
    dec a ; decrement buffer byte count
    ld [TMP], a ; write buffer byte count
    ld a, [TMP2]
    dec a
    ld [TMP2], a

    cp a, 0 ; are we past x-coord 19?
    jp z, .nextRow

.checkBufferCount:
    ld a, [TMP]
    cp a, 0 ; are we done iterating through BYTES_PER_VBLANK bytes?
    jp nz, .loop

    jp .end

.nextRow:
    WriteByteCount TransitionSpiralMapBytesLeft

	; add $20 to destination address (so it skips to the next row)
    ld bc, 12
    add hl, bc

    WriteTempDestAddress

    GetByteCount TransitionSpiralMapBytesLeft

    ld a, 20
    ld [TMP2], a ; reset x-coord

    jp .checkBufferCount

.end:
    ld a, [TMP] ; load buffer byte count
    cp a, 0 ; are we done iterating through BYTES_PER_VBLANK bytes?
    jp nz, .loop ; if not, reiterate

    WriteTempSrcAddress  
    WriteTempDestAddress

    ret

Scene1Init::
    di

	WriteAddress Scene1Loop, Loop
	WriteAddress Stat1, StatVector
    WriteAddress VBlankLoad, VBlankVector
	WriteAddress Timer1, TimerVector

.WaitUntilSafe:
    ; wait until LCD is safe to turn off
    ld a, [rSTAT]
    and STATF_LCD
    jp nz, .WaitUntilSafe

    ; Change palette to black
	ld a, %10101010
	;ld [rBGP], a

    ld a, 0
    ld [rSCX], a

    ; Set load bools to false
    ld [Spiral1Loaded], a
    ld [Spiral2Loaded], a
    ld [SpiralMapLoaded], a

    ; Compute initial size of spiral1 and write it to RAM
    ld bc, spiral1_end - spiral1
    ld a, c
    ld [TransitionSpiral1BytesLeft], a
    ld a, b
    ld [TransitionSpiral1BytesLeft+1], a

    ; Compute initial size of spiral2 and write it to RAM
    ld bc, spiral2_end - spiral2
    ld a, c
    ld [TransitionSpiral2BytesLeft], a
    ld a, b
    ld [TransitionSpiral2BytesLeft+1], a

    ; Compute initial size of spiral2 and write it to RAM
    ld bc, spiral_map_end - spiral_map
    ld a, c
    ld [TransitionSpiralMapBytesLeft], a
    ld a, b
    ld [TransitionSpiralMapBytesLeft+1], a

    ; Get spiral1's address and write it to memory
    ld de, spiral1

    WriteTempSrcAddress

    ; Get the VRAM dest address and write it to memory
    ld hl, $9000
    
    WriteTempDestAddress

    ; reset the palette
	;ld a, %00011011
	;ld [rBGP], a

	;ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
	;ld [rLCDC], a

    ld a, 0
    ld [TransitionDone], a

    reti

; temporary VBlank interrupt while we load data into VRAM
VBlankLoad:
    ;call hUGE_dosound

    ld a, [TransitionDone]
    cp a, 0
    jp nz, .end

    ld a, [Spiral1Loaded]
    cp a, 0
    jp z, .LoadSpiral1

    ld a, [Spiral2Loaded]
    cp a, 0
    jp z, .LoadSpiral2

    ld a, [SpiralMapLoaded]
    cp a, 0
    jp z, .LoadSpiralMap

    jp .end

.LoadSpiral1:
    ; check spiral1 bytes left
    ; is it zero? if so, check spiral2 bytes
    ; is spiral2 byte count zero? if so, check spiral_map bytes
    ; is spiral_map byte count zero? if so, then TransitionLoading should be 0

    GetByteCount TransitionSpiral1BytesLeft

    call LoadingMemCpy

    WriteByteCount TransitionSpiral1BytesLeft

    ; is data finished loading?
    ld a, [DataLoaded]
    cp a, 1
    jp z, .Spiral1Finished
    jp .end

.Spiral1Finished:
    ld a, 1
    ld [Spiral1Loaded], a

    ld de, spiral2

    WriteTempSrcAddress

    ld hl, $8800

    WriteTempDestAddress

    ; reset data loaded bool
    ld a, 0
    ld [DataLoaded], a

    ; Change palette to dark gray
	ld a, %10101010
	;ld [rBGP], a

    jp .end

.LoadSpiral2:
    GetByteCount TransitionSpiral2BytesLeft

    call LoadingMemCpy

    WriteByteCount TransitionSpiral2BytesLeft

    ; is data finished loading?
    ld a, [DataLoaded]
    cp a, 1
    jp z, .Spiral2Finished
    jp .end

.Spiral2Finished:
    ld a, 1
    ld [Spiral2Loaded], a

    ld de, spiral_map

    WriteTempSrcAddress

    ld hl, $9800
    ; init x-coord
    ld a, 20
    ld [TMP2], a

    WriteTempDestAddress

    ; reset data loaded bool
    ld a, 0
    ld [DataLoaded], a

    ; Change palette to light gray
	ld a, %01010101
	;ld [rBGP], a

    jp .end

.LoadSpiralMap:
    GetByteCount TransitionSpiralMapBytesLeft

    call LoadingMemCpyScrn

    WriteByteCount TransitionSpiralMapBytesLeft

    ; is data finished loading?
    ld a, [DataLoaded]
    cp a, 1
    jp z, .SpiralMapFinished
    jp .end

.SpiralMapFinished:
    ld a, 1
    ld [SpiralMapLoaded], a

    ; reset data loaded bool
    ld a, 0
    ld [DataLoaded], a

    ; we're done loading, so swap vblank interrupts
    WriteAddress VBlank1, VBlankVector

	ld a, %00011011
	ld [rBGP], a
.end:
   reti

VBlank1:
    call hUGE_dosound
    reti

Stat1:
    ;ld a, [rSCX]
    ;inc a
    ;ld [rSCX], a
    reti

Timer1:
    reti

Scene1Loop:
    halt
    jp Scene1Loop