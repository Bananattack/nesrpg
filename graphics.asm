REG_PPUCTRL = $2000
PPUCTRL_NAMETABLE_0 = $00
PPUCTRL_NAMETABLE_1 = $01
PPUCTRL_NAMETABLE_2 = $02
PPUCTRL_NAMETABLE_3 = $03
PPUCTRL_VRAM_STEP_X = $00
PPUCTRL_VRAM_STEP_Y = $04
PPUCTRL_SPR_PAT_0 = $00
PPUCTRL_SPR_PAT_1 = $08
PPUCTRL_BG_PAT_0 = $00
PPUCTRL_BG_PAT_1 = $10
PPUCTRL_SPR_8x8 = $00
PPUCTRL_SPR_8x16 = $20
; $40 is unused
PPUCTRL_NMI = $80
PPUCTRL_DISABLE = $00

REG_PPUMASK = $2001
PPUMASK_GREYSCALE = $01
PPUMASK_LEFTMOST_BG = $02
PPUMASK_LEFTMOST_SPR = $04
PPUMASK_RENDER_BG = $08
PPUMASK_RENDER_SPR = $10
PPUMASK_INTENSIFY_R = $20
PPUMASK_INTENSIFY_G = $40
PPUMASK_INTENSIFY_B = $80
PPUMASK_DISABLE = $00
PPUMASK_ENABLE = $1E

REG_PPUSTATUS = $2002
REG_OAMADDR = $2003
REG_OAMDATA = $2003
REG_PPUSCROLL = $2005
REG_PPUADDR = $2006
REG_PPUDATA = $2007

REG_OAMDMA = $4014
OAM_ATTR_PAL_0 = $00
OAM_ATTR_PAL_1 = $01
OAM_ATTR_PAL_2 = $02
OAM_ATTR_PAL_3 = $03
OAM_ATTR_PRIORITY = $20
OAM_ATTR_FLIP_X = $40
OAM_ATTR_FLIP_Y = $80


    ;.macro PrepareLoadSprite
    ;ldi16 \1, t0
    ;ldi16 \2, t2
    ;ldi8 \3, t4
    ;ldi8 \4, t5
    ;ldi8 \5, t6
    ;.endm


; Load map of metatiles into nametable
; where t0/t1 points to the map , and t2/t3 point to the tileset (metatile arrangements).
; BOTH OF THESE MUST BE PAGE-ALIGNED POINTERS, so t0 and t2 should be $00.
LoadMap:
    lda REG_PPUSTATUS ; Read PPU status to reset the high/low latch
    lda #$20 
    sta REG_PPUADDR ; Indicate high address byte
    lda #$00
    sta REG_PPUADDR ; Indicate low address byte
LoadMap_RowLoop:
    ldx #$00
LoadMap_CopyTop:
    txa ; Transfer x to a
    tay ; then transfer a to y
    lda [t0], y ; a = (*map)[y]
    clc
    asl a ; multiply by four
    asl a
    tay ; then transfer a to y again
    
    lda [t2], y ; a = (*tileset)[y]
    sta REG_PPUDATA ; copy a to PPU.
    iny ; y++
    lda [t2], y ; a = (*tileset)[y]
    sta REG_PPUDATA ; copy a to PPU.
    
    inx ; x++
    cpx #16 ; Full row of 16 copied? If not, keep going.
    bne LoadMap_CopyTop
    
    ldx #$00
LoadMap_CopyBottom:
    txa ; Transfer x to a
    tay ; then transfer a to y
    lda [t0], y ; a = (*map)[y]
    clc
    asl a ; multiply by four
    asl a
    add #02 ; add two
    tay ; then transfer a to y again
    
    lda [t2], y ; a = (*tileset)[y]
    sta REG_PPUDATA ; copy a to PPU.
    iny ; y++
    lda [t2], y ; a = (*tileset)[y]
    sta REG_PPUDATA ; copy a to PPU.
    
    inx ; x++
    cpx #16 ; Full row of 16 copied? If not, keep going.
    bne LoadMap_CopyBottom
    
    lda t0 ; a = t0
    add #16 ; a = a + 16
    sta t0 ; t0 = a
    cmp #240 ; t0 < 240? loop again.
    bltu LoadMap_RowLoop
LoadMap_Exit:
    rts
    
; Load attributes of tiles into nametable
; where t0/t1 points to the map. 00 = 0, 64 = 1, 128 = 2, 192 = 3
; THIS MUST BE A PAGE-ALIGNED POINTER, so t0 should be $00
; t2 = temporary attribute holder.
; t3 = tile count
LoadAttributes:
    lda REG_PPUSTATUS ; Read PPU status to reset the high/low latch
    lda #$23 
    sta REG_PPUADDR ; Indicate high address byte
    lda #$C0
    sta REG_PPUADDR ; Indicate low address byte
    lda #$00
    sta t3
LoadAttributes_RowLoop:
    ldx #$00
    stx t2
LoadAttributes_Copy:
    txa ; Transfer x to a
    tay ; then transfer a to y
    lda [t0], y ; a = (*map)[y]
    and #$c0 ; AA000000
    lsr a ; 1
    lsr a ; 2
    lsr a ; 3
    lsr a ; 4
    lsr a ; 5
    lsr a ; 6 -> 000000AA
    sta t2
    
    iny
    lda [t0], y ; a = (*map)[y]
    and #$c0 ; BB000000
    lsr a ; 1
    lsr a ; 2
    lsr a ; 3
    lsr a ; 4 -> 0000BB00
    ora t2 ; -> 0000BBAA
    sta t2
    
    txa ; Transfer x to a
    add #16 ; a = a + 16 row (1 row of metatiles)
    tay ; then transfer a to y
    lda [t0], y ; a = (*map)[y]
    and #$c0 ; CC000000
    lsr a ; 1
    lsr a ; 2 -> 00CC0000
    ora t2 ; -> 00CCBBAA
    sta t2

    iny
    lda [t0], y ; a = (*map)[y]
    and #$c0 ; DD000000
    ora t2 ; -> DDCCBBAA
    sta REG_PPUDATA
    inc t3
    
    inx
    inx
    cpx #16 ; Full row of 16 copied? If not, keep going.
    bne LoadAttributes_Copy

    lda t0 ; a = t0
    add #32 ; a = a + 32 (2 rows of metatiles)
    sta t0 ; t0 = a
    
    lda t3 ; a = t3
    cmp #56 ; t3 < 56? (ie. haven't copied up to second-last row of attributes) Then loop again.
    bltu LoadAttributes_RowLoop
    
    ldx #$00
    stx t2
LoadAttributes_CopyFinalRow: ; Last row is 1/2 the height of the rest.
    txa ; Transfer x to a
    tay ; then transfer a to y
    lda [t0], y ; a = (*map)[y]
    and #$c0 ; AA000000
    lsr a ; 1
    lsr a ; 2
    lsr a ; 3
    lsr a ; 4
    lsr a ; 5
    lsr a ; 6 -> 000000AA
    sta t2
    
    iny
    lda [t0], y ; a = (*map)[y]
    and #$c0 ; BB000000
    lsr a ; 1
    lsr a ; 2
    lsr a ; 3
    lsr a ; 4 -> 0000BB00
    ora t2 ; -> 0000BBAA
    sta REG_PPUDATA
    inc t3

    inx
    inx
    cpx #16 ; Full row of 16 copied? If not, keep going.
    bne LoadAttributes_CopyFinalRow
LoadAttributes_Exit:
    lda REG_PPUSTATUS
    lda #$00
    sta REG_PPUSCROLL
    sta REG_PPUSCROLL
    rts

; Load 16xheight sprite
; where t0/t1 = src sprite info, t2/t3 = destination sprite OAM, t4 = sprite x, t5 = sprite y, t6 = frame number, t7 = direction
; local t8
LoadSprite16:
    ldy #$00
    lda [t0], y ; read height
    inc t0
    sta t8 ; t8 = height
    tax ; also transfer to x
    
    lda t6 ; frame number = how many to seek
    clc
    asl a
    asl a ; multiply that by 4 bytes (shift left twice)

    lsr t8 ; divide t8 by 2
    beq AfterMultByHeight ; is zero? skip multiplication.
; multiply by height (where height is some power-of-two)
MultByHeight:
    asl a ; multiply a by 2
    lsr t8 ; divide t8 by 2
    bne MultByHeight ; is non-zero? multiply again.
AfterMultByHeight:
    sta t6 ; t6 now contains the number of bytes to skip over.
    
    lda t0 ; load t0
    add t6 ; add t6
    sta t0 ; t0 now points to the correct frame
    
    lda t7 ; check t7, if zero, don't flip.
    beq LoadSprite16LoopNoFlip
LoadSprite16LoopFlip:
    ; left column
    lda t5 ; load y
    sta [t2], y ; store y coordinate
    inc t2
    lda [t0], y ; read frame
    inc t0
    sta [t2], y ; store frame
    inc t2
    lda t7 ; load direction
    lda [t0], y ; read attr
    inc t0
    ora #$40 ; set horizontal flip
    sta [t2], y ; store attr
    inc t2
    lda t4 ; load x
    add #8 ; add 8
    sta [t2], y ; store x
    inc t2

    ; right column
    lda t5 ; load y
    sta [t2], y ; store y coordinate
    inc t2
    lda [t0], y ; read frame
    inc t0
    sta [t2], y ; store frame
    inc t2
    lda [t0], y ; read attr
    inc t0
    ora #$40 ; set horizontal flip
    sta [t2], y ; store attr
    inc t2
    lda t4 ; load x
    sta [t2], y ; store x
    inc t2    
    
    ; Increase row by 8
    lda t5
    add #8
    sta t5
    
    dex ; x--
    bne LoadSprite16LoopFlip ; exit when x == 0
    jmp LoadSprite16Exit
LoadSprite16LoopNoFlip:
    ; left column
    lda t5 ; load y
    sta [t2], y ; store y coordinate
    inc t2
    lda [t0], y ; read frame
    inc t0
    sta [t2], y ; store frame
    inc t2
    lda t7 ; load direction
    lda [t0], y ; read attr
    inc t0
    sta [t2], y ; store attr
    inc t2
    lda t4 ; load x
    sta [t2], y ; store x
    inc t2

    ; right column
    lda t5 ; load y
    sta [t2], y ; store y coordinate
    inc t2
    lda [t0], y ; read frame
    inc t0
    sta [t2], y ; store frame
    inc t2
    lda [t0], y ; read attr
    inc t0
    sta [t2], y ; store attr
    inc t2
    lda t4 ; load x
    add #8 ; add 8
    sta [t2], y ; store x
    inc t2    
    
    ; Increase row by 8
    lda t5
    add #8
    sta t5
    
    dex ; x--
    bne LoadSprite16LoopNoFlip ; exit when x == 0
LoadSprite16Exit:
    rts