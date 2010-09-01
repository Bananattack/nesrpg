; INES Header.
    ; See http://wiki.nesdev.com/w/index.php/TKROM
    .inesprg 8 ; How many 16KB PRGROM banks
    .ineschr 16 ; How many 8KB CHRROM banks
    .inesmap 4 ; Uses the MMC3 mapper
    .inesmir 0 ; Mirroring flag. Doesn't really matter either way here, since it's set in the MMC3 mapper itself.

; Variables
    .rsset $0000
t0 .rs 1
t1 .rs 1
t2 .rs 1
t3 .rs 1
t4 .rs 1
t5 .rs 1
t6 .rs 1
t7 .rs 1
t8 .rs 1
t9 .rs 1
tA .rs 1
tB .rs 1
tC .rs 1
tD .rs 1
tE .rs 1
tF .rs 1

; Request to update the sprites.
; Once set, the main loop must wait for the vblank to acknowledge it before continuing.
updateSprites .rs 1
; Request to update palette entries.
updatePal .rs 1
; Request to clear the timer in the vblank interrupt.
; This prevents overflow from happening.
clearTimer .rs 1
; Timer that is incremented on vblank interrupts.
frameTimer .rs 1

; Count which IRQ we're on
irqCounter .rs 1

; Localized copy of frameTimer which won't change if vblank occurs unless logic is complete.
; Essentially gives a measure of how many frames have occurred since last update.
mainTimer .rs 1
; Loading inputs.
controls .rs 1

; Color to fade to.
fadeColor .rs 1
; Fade table to view
fadeTableLow .rs 1
fadeTableHigh .rs 1
; Fade level
; 0..1 = use palette entry
; 2..8 = fadeTable[floor(fadeLevel / 2) * 64 + palette entry]
; 9..10 = use fade Color
fadeLevel .rs 1
; 0 = no change to fade level
; 1 = decrease fade level (until fully off)
; 2 = increase fade level (until fully on)
fadeDirection .rs 1

; Text print location.
textX .rs 1
textY .rs 1
; Pointer to text.
textBufferLow .rs 1
textBufferHigh .rs 1
; Tell the PPU to write the character to screen?
textWrite .rs 1

cloudScroll .rs 1
cloudScroll2 .rs 1
cloudScrollFraction .rs 1

SPRITE_RAM = $0200
activePalette = $0300 ; Where the colors, prior to effect application go.
resultPalette = $0320 ; Where the colors, after effect application end up. Copy this to VRAM.

; Low PRG ROM
    .bank 14
    .org $c000
    ; Helper code
    .include "helper.asm"
    .include "graphics.asm"
    .include "controls.asm"
    .include "mmc3.asm"

; Updpate player spritesheet
PlayerLoad:
    ldx #$00
    ; load player sprite at memory $0200, at point (playerX, playerY), with frame playerFrame facing direction playerDirection
    ldi16 player_sprite, t0
    ldi16 $0200, t2
    lda #$18 ; X
    sta t4
    lda #$70 ; Y
    sta t5
    lda #$00 ; Frame
    sta t6
    lda #$00 ; Direction
    sta t7
    jsr LoadSprite16
    rts

LoadCursor:
    lda #$08
    asl a
    asl a ; multiply by 4
    tax
    lda #($B8-1) ; y
    sta SPRITE_RAM, x
    inx
    lda #$03 ; tile
    sta SPRITE_RAM, x
    inx
    lda #$00 ; attr
    sta SPRITE_RAM, x
    inx
    lda #$10 ; x
    sta SPRITE_RAM, x
    inx
    rts

; Loads a palette into RAM.
SwitchActivePal:
    ldx #$00
SwitchActivePal_Loop:
    lda palette, x ; TODO REPLACE THIS WHEN PALETTES SWITCH AT RUNTIME
    sta activePalette, x
    inx
    cpx #$20
    bne SwitchActivePal_Loop
    rts

ApplyPalFade:
    ldx #$00
ApplyPalFade_Loop:
    lda fadeLevel
    lsr a
    beq ApplyPalFade_NoFade
ApplyPalFade_Fade:
    cmp #$05
    bltu ApplyPalFade_PartialFade
ApplyPalFade_FullFade:
    lda fadeColor
    jmp ApplyPalFade_SetColor
ApplyPalFade_PartialFade:
    sub #$01 ; Row in table is fadeLevel - 1
    asl a ; 1
    asl a ; 2
    asl a ; 3
    asl a ; 4
    asl a ; 5
    asl a ; 6 multiply row by 64
    ora activePalette, x ; Add current palette index to get index in table.
    tay
    lda [fadeTableLow], y
    jmp ApplyPalFade_SetColor
ApplyPalFade_NoFade:
    lda activePalette, x
ApplyPalFade_SetColor:
    sta resultPalette, x
	inx
	cpx #$20
	bne ApplyPalFade_Loop
    rts
    
UpdateFade:
    lda fadeDirection
    beq UpdateFade_End ; direction == 0: no fade application
    and #$01
    beq UpdateFade_FadeOut
UpdateFade_FadeIn:
    dec fadeLevel ; Decrease fadeLevel
    jsr ApplyPalFade ; Apply changes
    lda fadeLevel
    beq UpdateFade_Stop ; fading in and fadeLevel is none? stop.
    jmp UpdateFade_End    
UpdateFade_FadeOut:
    inc fadeLevel ; Increase fadeLevel
    jsr ApplyPalFade ; Apply changes
    lda fadeLevel
    cmp #$0A
    beq UpdateFade_Stop ; fading out and fadeLevel is full? stop.
    jmp UpdateFade_End
UpdateFade_Stop:
    lda #$00
    sta fadeDirection
UpdateFade_End:
    rts

CopyPal:
    lda REG_PPUSTATUS
    lda #$3F
    sta REG_PPUADDR
    lda #$00
    sta REG_PPUADDR
    ldx #$00
CopyPal_Loop:
    lda resultPalette, x
	sta REG_PPUDATA
	inx
	cpx #$20
	bne CopyPal_Loop
    rts
    
Reset:
    sei ; Disable IRQ
    cld ; Disable decimal/BCD mode
    ldi8 #$40, $4017 ; Disable APU frame IRQ
    clsi ; Clear stack, setting s = x = #$ff
    inx ; Increment to wrap to x = 0 again
    stx $2000 ; Disable NMI
    stx $2001 ; Disable rendering
    ;stx $4010 ; Disable any DMC IRQ.
Reset_WaitForVBlank:
    bit REG_PPUSTATUS ; Check for vblank
    bpl Reset_WaitForVBlank ; Wait for vblank interval to make sure the PPU is ready
Reset_ClearRAM: ; Assumes x = 0
    lda #$00
    sta $00, x ; mem[... + x] = $00
    sta $0100, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    lda #$fd
    sta SPRITE_RAM, x ; mem[SPRITE_RAM + x] = offscreen location
    inx ; x++
    bne Reset_ClearRAM ; Repeat until pages are filled (x overflows to 0)
Reset_WaitForVBlank2:
    bit REG_PPUSTATUS ; Check for vblank.
    bpl Reset_WaitForVBlank2 ; Wait for vblank interval to make sure the PPU is ready
    
Main:
Main_LoadText:
    lda #$03
    sta textX
    lda #$17
    sta textY
    lda #LOW(stringTable)
    sta textBufferLow
    lda #HIGH(stringTable)
    sta textBufferHigh
Main_LoadMap:
    lda #(PPUCTRL_NAMETABLE_0 | PPUCTRL_VRAM_STEP_X | PPUCTRL_BG_PAT_0 | PPUCTRL_SPR_PAT_1)
    sta REG_PPUCTRL
    lda #PPUMASK_DISABLE
    sta REG_PPUMASK
    
    lda #$0f
    sta fadeColor
    lda #LOW(fadeBlack)
    sta fadeTableLow
    lda #HIGH(fadeBlack)
    sta fadeTableHigh
    lda #$0a
    sta fadeLevel
    lda #$01
    sta fadeDirection
    
    jsr SwitchActivePal
    jsr ApplyPalFade
    jsr CopyPal
    jsr LoadCursor
    jsr PlayerLoad
    
    ; Map tiles
    lda #$00
    sta t0
    sta t2
    lda #HIGH(map)
    sta t1
    lda #HIGH(tileset)
    sta t3
    jsr LoadMap
    ; Map attributes
    lda #$00
    sta t0
    lda #HIGH(map)
    sta t1
    jsr LoadAttributes
Main_InitDisplay:
    ; Load CHR bank
    lda #(MMC3_SELECT_2K_CHR_00)
    sta REG_MMC3_SELECT
    lda #$00
    sta REG_MMC3_DATA
    lda #(MMC3_SELECT_2K_CHR_08)
    sta REG_MMC3_SELECT
    lda #$02
    sta REG_MMC3_DATA

    lda #(PPUCTRL_NAMETABLE_0 | PPUCTRL_VRAM_STEP_X | PPUCTRL_BG_PAT_0 | PPUCTRL_SPR_PAT_1 | PPUCTRL_NMI)
    sta REG_PPUCTRL
    lda #(PPUMASK_ENABLE)
    sta REG_PPUMASK
    lda #$01
    sta updateSprites ; Tell NMI to update sprites
    
    cli ; Allow IRQ.
Main_Loop:
Main_UpdateTimer:
    lda clearTimer
    bne Main_WaitForSpriteUpdate ; Already played with timer, waiting on vblank.
    lda frameTimer ; Load the frame timer.
    sta mainTimer ; Localize a copy.
    beq Main_WaitForSpriteUpdate ; Skip updating if there is none to be done
    lda #$01
    sta clearTimer ; Reset timer once
Main_UpdateLogic:
    jsr UpdateControls
    ; Do important game step-wise logic here.
    jsr UpdateFade
Main_TextboxCheck:
    lda textWrite ; If character hasn't been written, don't write.
    bne Main_UpdateLogicCheckDone
Main_TextboxWrite:
    ldy #$00
    lda [textBufferLow], y ; Read a character
    beq Main_UpdateLogicCheckDone ; If character is null-terminator, then stop.
    
    inc textBufferLow ; Advance buffer
Main_TextboxCheckNewline:
    cmp #$0A ; Newline?
    bne Main_TextboxWriteNormal
    lda #$02
    sta textX
    inc textY
    jmp Main_TextboxWrite ; read another character.
Main_TextboxWriteNormal:
    sta textWrite ; Write character to screen
Main_UpdateLogicCheckDone:
    dec mainTimer ; Decrement timer
    bne Main_UpdateLogic ; Repeat until timer is 0 again.
Main_WaitForSpriteUpdate:
    lda updateSprites
    bne Main_WaitForSpriteUpdate ; Wait until sprites are ready for another update.
    ; Do important sprite and tile modifications here.
    lda #$01
    sta updateSprites ; Tell NMI we're ready to update sprites    
    jmp Main_Loop ; Repeat
    
    
NMI:
    ; Save registers.
    pha ; push (a)
    txa ; save x
    pha ; push
    tya ; save y
    pha ; push
    
    sta REG_MMC3_IRQ_DISABLE ; Acknowledge any interrupts
    
    jsr CopyPal
    
    ; Revert CHR bank
    lda #(MMC3_SELECT_2K_CHR_08)
    sta REG_MMC3_SELECT
    lda #$02
    sta REG_MMC3_DATA
    
NMI_CheckTimerStatus:
    lda clearTimer
    beq NMI_IncrementTimer ; If clearTimer is false, then skip to incrementing frame timer.
    lda #$00 ; Otherwise, clear both the clearTimer and frameTimer flags.
    sta frameTimer ; Clear the frame timer
    sta clearTimer ; Make clearTimer false to allow another clear request.
    jmp NMI_CheckUpdateSprites ; Skip to display update
NMI_IncrementTimer:
    inc frameTimer ; frameTimer++
NMI_CheckUpdateSprites:
    lda updateSprites ; Update display?
    beq NMI_DrawText ; If false, skip past this.
    lda #$00 ; Otherwise, start the DMA.
    sta REG_OAMADDR ; set the low byte (00) of the RAM address
    lda #$02
    sta REG_OAMDMA ; set the high byte (02) of the RAM address, start the transfer
    dec updateSprites ; Notify that sprites have been updated
    
NMI_DrawText:
    lda textWrite
    beq NMI_Cleanup ; If textWrite is false, then skip this.
    lda REG_PPUSTATUS ; Read PPU status to reset the high/low latch
    lda textY
    lsr a ; 1
    lsr a ; 2
    lsr a ; 3. divide by 2^3 = 8.
    add #$20 ; Location of nametable
    sta REG_PPUADDR ; Indicate high address byte
    lda textY
    asl a ; 1
    asl a ; 2
    asl a ; 3
    asl a ; 4
    asl a ; 5. multiply by 2^5 = 32.
    add textX ; Add the x position
    sta REG_PPUADDR ; Indicate low address byte
    lda textWrite ; Load letter
    add #$80 ; Add $80 = textchar - $10 + $A0
    sta REG_PPUDATA ; Write letter to screen
    lda #$00 ;
    inc textX ; Advance cursor location
    sta textWrite ; Indicate the text has been written
    
NMI_Cleanup:
    ; Setup MMC3 scanline interrupts
    ;lda #159 ; After (n + 1) = 160 lines, draw textbox
    lda #0
    sta irqCounter
    lda #71
    sta REG_MMC3_IRQ_LATCH ; Set IRQ latch
    sta REG_MMC3_IRQ_RELOAD ; Reload IRQ counter
    sta REG_MMC3_IRQ_DISABLE ; Latch in the countdown value
    sta REG_MMC3_IRQ_ENABLE ; Enable the IRQ counter

    ; No scroll.
    inc cloudScrollFraction
    lda cloudScrollFraction
    and #$07
    bne NMI_ScrollCloud
    dec cloudScroll2
    lda cloudScrollFraction
    and #$07
    bne NMI_ScrollCloud
    inc cloudScroll
NMI_ScrollCloud:
    lda #(PPUCTRL_NAMETABLE_0 | PPUCTRL_VRAM_STEP_X | PPUCTRL_BG_PAT_0 | PPUCTRL_SPR_PAT_1 | PPUCTRL_NMI)
    sta REG_PPUCTRL

    lda REG_PPUSTATUS
    lda cloudScroll2
    sta REG_PPUSCROLL
    lda #$00
    sta REG_PPUSCROLL
    
    
    ; Restore registers.
    pla ; pull
    tay ; restore y
    pla ; pull
    tax ; restore x
    pla ; pull (a)
    ; Done!
    rti
    
IRQ:
    ; Save registers.
    pha ; push (a)
    txa ; save x
    pha ; push
    tya ; save y
    pha ; push
    
    sta REG_MMC3_IRQ_DISABLE ; Acknowledge any interrupts and disable further IRQ
    lda irqCounter
    bne IRQ_1 ; Nonzero IRQ.
IRQ_0:
    ; Scroll.
    lda #(PPUCTRL_NAMETABLE_0 | PPUCTRL_VRAM_STEP_X | PPUCTRL_BG_PAT_0 | PPUCTRL_SPR_PAT_1 | PPUCTRL_NMI)
    sta REG_PPUCTRL
    
    lda #$00
    sta REG_PPUSCROLL
    sta REG_PPUSCROLL
    
    inc irqCounter
    ;lda #87
    lda #103
    ;lda #31
    sta REG_MMC3_IRQ_LATCH ; Set IRQ latch
    sta REG_MMC3_IRQ_RELOAD ; Reload IRQ counter
    sta REG_MMC3_IRQ_DISABLE ; Latch in the countdown value
    sta REG_MMC3_IRQ_ENABLE ; Enable the IRQ counter again
    jmp IRQ_Cleanup
IRQ_1:
; BEGIN UNUSED CODE ---
    .if 0
    ; Make sure it's IRQ #2, otherwise jump to IRQ_2.
    cmp #$01
    bne IRQ_2 ; Not 1st, jump to next IRQ.

    ; No scroll.
    lda REG_PPUSTATUS
    lda #$00
    sta REG_PPUSCROLL
    sta REG_PPUSCROLL
    lda REG_PPUSTATUS
    
    inc irqCounter
    lda #87
    sta REG_MMC3_IRQ_LATCH ; Set IRQ latch
    sta REG_MMC3_IRQ_RELOAD ; Reload IRQ counter
    sta REG_MMC3_IRQ_DISABLE ; Latch in the countdown value
    sta REG_MMC3_IRQ_ENABLE ; Enable the IRQ counter again
    jmp IRQ_Cleanup
    .endif
; --- END OF UNUSED CODE
;IRQ_2:
    lda #(MMC3_SELECT_2K_CHR_00)
    sta REG_MMC3_SELECT
    lda #$00
    sta REG_MMC3_DATA
    
    lda #(MMC3_SELECT_2K_CHR_08)
    sta REG_MMC3_SELECT
    lda #$0A
    sta REG_MMC3_DATA
IRQ_Cleanup:
    ; Restore registers.
    pla ; pull
    tay ; restore y
    pla ; pull
    tax ; restore x
    pla ; pull (a)
    ; Done!
    rti
    

; Setup interrupts.
    .bank 15
    .org $E000
    ; Global palette entry
PAL_BG = $0f
    ; Palette
palette:
    ; tiles
    .db PAL_BG, $10, $11, $30
    .db PAL_BG, $29, $11, $19
    .db PAL_BG, $0f, $0f, $0f
    .db PAL_BG, $0f, $0f, $0f
    ; sprites
    .db PAL_BG, $0f, $17, $37
    .db PAL_BG, $0f, $11, $21
    .db PAL_BG, $0f, $05, $05
    .db PAL_BG, $0f, $05, $05
    
    .org $E100
tileset:
    .db $00, $00 ; 00: blank
    .db $00, $00
    .db $fb, $fc ; 01: o-
    .db $fe, $20 ;     |.
    .db $fc, $fc ; 02: --
    .db $20, $20 ;    ..
    .db $fc, $fb ; 03: -o
    .db $20, $ff ;     .|
    .db $fe, $20 ; 04: |.
    .db $fe, $20 ;     |.
    .db $20, $ff ; 05: .|
    .db $20, $ff ;     .|
    .db $20, $20 ; 06: ..
    .db $20, $20 ;     ..
    .db $fe, $20 ; 07: |.
    .db $fb, $fd ;     o-
    .db $20, $20 ; 08: ..
    .db $fd, $fd ;     --
    .db $20, $ff ; 09: .|
    .db $fd, $fb ;     -o
    .db $12, $13 ; 0A - cloud
    .db $22, $23 ; 
    .db $14, $15 ; 0B
    .db $24, $25 ; 
    .db $16, $17 ; 0C
    .db $26, $27 ; 
    .db $18, $20 ; 0D
    .db $28, $20 ;
    .db $32, $33 ; 0E
    .db $42, $43 ; 
    .db $34, $35 ; 0F
    .db $44, $45 ; 
    .db $36, $37 ; 10
    .db $46, $47 ;
    .db $38, $20 ; 11
    .db $48, $20 ;
    .db $20, $20 ; 12 - grass
    .db $E0, $E1 ;
    .db $20, $20 ; 13
    .db $E2, $E3 ; 
    .db $20, $20 ; 14
    .db $E4, $E5 ; 
    .db $20, $20 ; 15
    .db $E6, $E7 ; 
    .db $20, $20 ; 16
    .db $E8, $E9 ;
    .db $20, $20 ; 17
    .db $EA, $EB ;     
    .db $F0, $F1 ; 18 - grass
    .db $00, $00 ; 
    .db $F2, $F3 ; 19
    .db $00, $00 ; 
    .db $F4, $F5 ; 1A
    .db $00, $00 ;
    .db $F6, $F7 ; 1B
    .db $00, $00 ;
    .db $F8, $F9 ; 1C
    .db $00, $00 ;
    .db $FA, $FB ; 1D
    .db $00, $00 ;
    .db $19, $1A ; 1E
    .db $29, $2A ;
    .db $1B, $00 ; 1F
    .db $2B, $00 ;
    .db $39, $3A ; 20
    .db $49, $4A ;
    .db $3B, $3C ; 21
    .db $4B, $4C ;
    .db $01, $fb ; 22 xo. where : = black . = background x = stripe, o = corner of box
    .db $10, $fe ;    :|
    .db $01, $00 ; 23 --
    .db $00, $01 ;    $$ UNUSED
    .db $fb, $01 ; 24 ox
    .db $ff, $10 ;    |:
    .db $10, $fe ; 25 :|
    .db $10, $fe ;    :|
    .db $ff, $10 ; 26 |:
    .db $ff, $10 ;    |: 
    .db $01, $fb ; 27 xo
    .db $11, $11 ;    ##
    .db $fd, $fd ; 28 -- 
    .db $11, $11 ;    ##
    .db $fb, $01 ; 29 ox where # = strong diagonal stripe
    .db $11, $11 ;    ##
    
    .org $E200
map:
    ; 8
    .db $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06
    .db $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $0A, $0B, $0C, $0D, $06, $06
    ; 16
    .db $06, $06, $0A, $0B, $0C, $0D, $06, $06, $06, $06, $0E, $0F, $10, $11, $06, $06
    .db $06, $06, $0E, $0F, $10, $11, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06 
    ; 24
    .db $52, $53, $54, $55, $56, $57, $52, $53, $54, $55, $56, $57, $52, $53, $54, $55
    .db $58, $59, $5A, $5B, $5C, $5D, $58, $59, $5A, $5B, $5C, $5D, $58, $59, $5A, $5B
    ; 32
    .db $40, $5E, $5F, $40, $40, $40, $40, $40, $40, $40, $40, $40, $60, $61, $40, $40
    .db $40, $40, $40, $40, $40, $40, $40, $5E, $5F, $40, $40, $40, $40, $40, $40, $40
    ; 40
    .db $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40
    .db $40, $40, $40, $60, $61, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40
    ; 48
    .db $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $5E, $5F, $40, $40, $40
    .db $22, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $24
    ; 56
    .db $25, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $26
    .db $25, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $06, $26
    ; 64
    .db $27, $28, $28, $28, $28, $28, $28, $28, $28, $28, $28, $28, $28, $28, $28, $29
    
    .org $E300
stringTable:
    ;    01234567890123456
    .db "Hello world!\nThis is a test.\n1, 2, 3, 4, 5, 6, 7...\n\nHooray. Good job, me!", 0
    
    .org $E400
fadeBlack:
    .incbin "fade_0f.bin"
    
    .org $E500
fadeWhite:
    .incbin "fade_30.bin"
    
    .org $E600
player_sprite:
    .include "player.spr"
    
    .org $FFFA
    .dw NMI
    .dw Reset
    .dw IRQ
    
; Import sprites.
    .bank 16
    .org $0000
    .incbin "battle_tiles.chr"
    .org $1000
    .incbin "sprite_tiles.chr"
    
    .bank 17
    .org $0000
    .incbin "font_tiles.chr"
    
    .bank 18
    .org $0000
    .bank 19
    .org $0000
    .bank 20
    .org $0000
    .bank 21
    .org $0000
    .bank 22
    .org $0000
    .bank 23
    .org $0000
    .bank 24
    .org $0000
    .bank 25
    .org $0000
    .bank 26
    .org $0000
    .bank 27
    .org $0000
    .bank 28
    .org $0000
    .bank 29
    .org $0000
    .bank 30
    .org $0000
    .bank 31
    .org $0000
    
