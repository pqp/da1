MACRO WriteVector
	ld a, l
	ld [de], a
	ld a, h
	inc de
	ld [de], a
ENDM

Macro WriteAddress
    ld a, LOW(\1)
    ld [\2], a
    ld a, HIGH(\1)
    ld [(\2)+1], a
ENDM

Macro GetByteCount
    ld a, [\1]
    ld c, a
    ld a, [(\1)+1]
    ld b, a
ENDM

Macro WriteByteCount
    ld a, c
    ld [\1], a
    ld a, b
    ld [(\1)+1], a
ENDM

Macro WriteTempSrcAddress
    ld a, e
    ld [TempSrcAddress], a
    ld a, d
    ld [TempSrcAddress+1], a
ENDM

Macro WriteTempDestAddress
    ld a, l
    ld [TempDestAddress], a
    ld a, h
    ld [TempDestAddress+1], a
ENDM