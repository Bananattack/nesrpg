REG_JOY1 = $4016
REG_JOY2 = $4017

CONTROL_A = $01
CONTROL_B = $02
CONTROL_SELECT = $04
CONTROL_START = $08
CONTROL_UP = $10
CONTROL_DOWN = $20
CONTROL_LEFT = $40
CONTROL_RIGHT = $80

    ; Test control.
    ; Assumes x contains the controls.
    ; \1 is an immediate value representing the control to check.
    ; \2 is an immediate value representing the location to jump when not pressed.
    .macro TestControl
        txa
        and \1
        beq \2
    .endm

; Reads controller and stores the result in controls
; Derived from code posted by blargg on nesdevwiki
UpdateControls:
    ; Strobe controller
    lda #1
    sta REG_JOY1
    lda #0
    sta REG_JOY1
    ; Read all 8 buttons
    ldx #8
UpdateControlsLoop:
    ; Read next button state and mask off low 2 bits.
    ; Compare with $01, which will set carry flag if
    ; either or both bits are set.
    lda REG_JOY1
    and #$03
    cmp #$01
    ; Now, rotate the carry flag into the top of A,
    ; land shift all the other buttons to the right
    ror controls
    dex
    bne UpdateControlsLoop
    ; Done
    rts
    