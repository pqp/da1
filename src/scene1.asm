include "hardware.inc"
include "charmap.inc"

SECTION "Scene 1", ROM0[$1200]

Scene1Init::
    di

    reti

VBlank1:
    call hUGE_dosound
    reti

Stat1:
    reti

Timer1:
    reti

Scene1Loop:
    halt
    jp Scene1Loop