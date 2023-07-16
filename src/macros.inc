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