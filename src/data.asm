include "charmap.inc"

SECTION "Bank 0", ROM0[$2000]

;;;;
;;;; for intro.asm
;;;;

DEF intro_string_def EQUS "\"Hello, world! 0123456789! This is a test string, and it is long. Hoo boy is it long. It is so long. Gosh, it has a length. @#$%&*() I mean, really. ~\""

intro_string::
	db intro_string_def
intro_string_len::
	db STRLEN(intro_string_def)

; swiped from the RGBDS docs
sine_table::
; Generate a 256-byte sine table with values in the range [0, 128]
; (shifted and scaled from the range [-1.0, 1.0])
ANGLE = 0.0
    REPT 256
        db (MUL(64.0, SIN(ANGLE)) + 64.0) >> 16
ANGLE = ANGLE + 256.0 ; 256.0 = 65536 degrees / 256 entries
    ENDR
sine_table_end::

carnival_ase_1::
INCBIN "res/carnival_ase.2bpp",0,2048
carnival_ase_1_end::

carnival_ase_2::
INCBIN "res/carnival_ase.2bpp",2048
carnival_ase_2_end::

/*
carnival_ase_palette:
INCBIN "res/carnival_ase.pal"
carnival_ase_palette_end:
*/

carnival_ase_tilemap::
INCBIN "res/carnival_ase.map"
carnival_ase_tilemap_end::

charset::
INCBIN "res/charset.2bpp",128
charset_end::

SECTION "Bank 1", ROMX

;goat::
;INCBIN "res/goat144_ase.2bpp"
;goat_end::

spiral1::
INCBIN "res/spiraali.2bpp",0,2048
spiral1_end::

spiral2::
INCBIN "res/spiraali.2bpp",2048
spiral2_end::

spiral_map::
INCBIN "res/spiraali.map"
spiral_map_end::