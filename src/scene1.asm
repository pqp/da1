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

SECTION "Scene 1", ROM0[$1200]

LoadingMemCpy:
    ; check byte count's most significant byte
    ld a, b
    cp a, 0 ; is it 0?
    jp z, .checkLeast ; if so, check the least significant byte
    jp .init ; otherwise, continue as usual

.checkLeast:
    ld a, c
    cp a, 16
    jp nz, .init ; if the value left is greater than 16, continue as usual
    ld a, 1 ; otherwise, indicate that this is the last byte for this chunk of data
    ld [DataLoaded], a

.init:
    ld a, 16
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
    ld a, [TMP]
    dec bc
    dec a
    ld [TMP], a

    cp a, 0
    jp nz, .loop 

    ld a, e
    ld [TempSrcAddress], a
    ld a, d
    ld [TempSrcAddress+1], a

    ld a, l
    ld [TempDestAddress], a
    ld a, h
    ld [TempDestAddress+1], a

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

    ; Turn palette off
	ld a, 0
	;ld [rBGP], a
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

    ld a, e
    ld [TempSrcAddress], a
    ld a, d
    ld [TempSrcAddress+1], a

    ; Get the VRAM dest address and write it to memory
    ld hl, $9000
    
    ld a, l
    ld [TempDestAddress], a
    ld a, h
    ld [TempDestAddress+1], a

    ; reset the palette
	;ld a, %00011011
	;ld [rBGP], a

	;ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
	;ld [rLCDC], a

    ld a, 0
    ld [TransitionDone], a

    reti

    /*
    ld a, 16
    ld [TMP], a
    ld de, spiral1
    ld a, [TransitionSpiral1Bytes]
    ld c, a
    ld a, [TransitionSpiral1Bytes+1]
    ld b, a
    ld hl, $9000
    add hl, bc

    call TransitionMemCopy

    ; Update byte count in memory
    ld a, c
    ld [TransitionSpiral1Bytes], a
    ld a, b
    ld [TransitionSpiral1Bytes+1], a

    ld a, b
    or a, c
    jp z, .Spiral1Done
    jp .end
*/

    ; check transitionspiral1 bytes
    ; is it zero? if so, we're done

    ; when we've loaded 16 bytes
    ; save the address we were reading from
    ; save the address we were writing to
    ; save the number of bytes left

    /*
    ; load tile data into VRAM
    ld de, spiral1
    ld bc, spiral1_end - spiral1
    ld hl, $9000
    call memcpy

    ld a, l
    ld [TransitionLoadAddress], a
    ld a, h
    ld [TransitionLoadAddress+1], a

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
    */

; temporary VBlank interrupt while we load data into VRAM
VBlankLoad:
    call hUGE_dosound

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

    ld a, [TransitionSpiral1BytesLeft]
    ld c, a
    ld a, [TransitionSpiral1BytesLeft+1]
    ld b, a

    call LoadingMemCpy

    ld a, c
    ld [TransitionSpiral1BytesLeft], a
    ld a, b
    ld [TransitionSpiral1BytesLeft+1], a

    ; is data finished loading?
    ld a, [DataLoaded]
    cp a, 1
    jp z, .Spiral1Finished
    jp .end

.Spiral1Finished:
    ld a, 1
    ld [Spiral1Loaded], a

    ld de, spiral2

    ld a, e
    ld [TempSrcAddress], a
    ld a, d
    ld [TempSrcAddress+1], a

    ld hl, $8800

    ld a, l
    ld [TempDestAddress], a
    ld a, h
    ld [TempDestAddress+1], a

    ; reset data loaded bool
    ld a, 0
    ld [DataLoaded], a

    jp .end

.LoadSpiral2:
    ld a, [TransitionSpiral2BytesLeft]
    ld c, a
    ld a, [TransitionSpiral2BytesLeft+1]
    ld b, a

    call LoadingMemCpy

    ld a, c
    ld [TransitionSpiral2BytesLeft], a
    ld a, b
    ld [TransitionSpiral2BytesLeft+1], a

    ; is data finished loading?
    ld a, [DataLoaded]
    cp a, 1
    jp z, .Spiral2Finished
    jp .end

.Spiral2Finished:
    ld a, 1
    ld [Spiral2Loaded], a

    ld de, spiral_map

    ld a, e
    ld [TempSrcAddress], a
    ld a, d
    ld [TempSrcAddress+1], a

    ld hl, $9800

    ld a, l
    ld [TempDestAddress], a
    ld a, h
    ld [TempDestAddress+1], a

    ; reset data loaded bool
    ld a, 0
    ld [DataLoaded], a

    jp .end

.LoadSpiralMap:
    ld a, [TransitionSpiralMapBytesLeft]
    ld c, a
    ld a, [TransitionSpiralMapBytesLeft+1]
    ld b, a

    call LoadingMemCpy

    ld a, c
    ld [TransitionSpiralMapBytesLeft], a
    ld a, b
    ld [TransitionSpiralMapBytesLeft+1], a

    ; is data finished loading?
    ld a, [DataLoaded]
    cp a, 1
    jp z, .SpiralMapFinished
    jp .end

.SpiralMapFinished:
    ld a, 1
    ld [SpiralMapLoaded], a

    /*
	ld a, 20
	ld [TMP], a
	ld hl, $9800
	ld bc, spiral_map_end - spiral1_end
	ld de, spiral_map
	call memcpy_scrn
    */

    ; reset data loaded bool
    ld a, 0
    ld [DataLoaded], a

    jp .end

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