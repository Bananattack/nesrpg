    .macro add ; Add immediate without carry.
        clc ; clear carry
        adc \1 ; add
    .endm
    
    .macro sub ; Subtract immediate without carry.
        sec ; set carry (clear borrow)
        sbc \1 ; subtract
    .endm
    
    .macro not ; Bitwise negation / one's complement of term
        eor #$ff
    .endm
    
; Load helpers.
    .macro ldi8 ; Load immediate 8-bit value \1 into location \2, using A as a temporary.
        lda #\1
        sta \2
    .endm
    
    .macro cl8 ; Clear 8-bit location \1, by setting A = 0.
        ldi8 0, \1
    .endm
    
    .macro ldi16 ; Load immediate 8-bit value \1 into location \2, using A as a temporary.
        lda	#LOW(\1)
        sta	\2
        lda	#HIGH(\1)
        sta	\2 + 1
    .endm
    
    .macro cl16 ; Clear 8-bit location \1, by setting A = 0.
        ldi16 0, \1
    .endm
    
    .macro ldsi ; Load stack with value \1
        ldx #\1 ; load value into x
        txs ; s = x
    .endm
    
    .macro clsi ; Clear stack by setting x to #$FF and then transferring to stack
        ldsi $FF
    .endm
    
; Branch helpers.
    .macro bltu
        bcc \1 ; jump if less-than
    .endm
    
    .macro bleu
        bcc \1 ; jump if less-than
        beq \1 ; jump if equal
    .endm
    
    .macro bgtu
        beq .x_\@ ; don't jump if equal
        bcs \1 ; jump if greater-than-or-equal (except previous instruction ensures only on greater-than)
.x_\@:
    .endm
    
    .macro bgeu
        bcs \1 ; jump if greater-than-or-equal
    .endm
    
; Branch helpers (signed)
    .macro blts
        bmi \1 ; jump if less-than (signed)
    .endm
    
    .macro bles
        bmi \1 ; jump if less-than (signed)
        beq \1 ; jump if equal
    .endm
    
    .macro bgts
        beq .x_\@ ; don't jump if equal
        bpl \1 ; jump if greater-than-or-equal (signed) (except previous instruction ensures only on greater-than)
.x_\@:
    .endm
    
    .macro bges
        bpl \1 ; jump if greater-than-or-equal (signed)
    .endm
    
; Long-branch
    .macro lbeq ; long branch if equal
        bne .x_\@
        jmp \1
.x_\@:
    .endm
    
    .macro lbne ; long branch if not equal
        beq .x_\@
        jmp \1
.x_\@:
    .endm
    
    .macro lbltu ; long branch if less-than
        bcs .x_\@ ; don't jump if greater-than-or-equal
        jmp \1 ; jump if <
.x_\@:
    .endm
    
    .macro lbleu ; long branch if less-than-or-equal
        bcs .test_\@ ; if >=, only jump if also equal.
        jmp \1
.test_\@:
        bne .fail_\@ ; don't jump if strictly > (ie. both >= and !=)
        jmp \1
.fail_\@:
    .endm
    
    .macro lbgtu ; long branch if greater-than
        bcc .x_\@ ; don't jump if less-than
        beq .x_\@ ; don't jump if equal
        jmp \1
.x_\@:
    .endm
    
    .macro lbgeu
        bcc .x_\@ ; don't jump if less-than
        jmp \1
.x_\@:
    .endm
    
    .macro lblts ; long branch if less-than (signed)
        bpl .x_\@ ; don't jump if greater-than-or-equal
        jmp \1 ; jump if <
.x_\@:
    .endm
    
    .macro lbles ; long branch if less-than-or-equal (signed)
        bpl .test_\@ ; if >=, check that it is equal.
        jmp \1
.test_\@:
        bne .fail_\@ ; don't jump if strictly > (ie. both >= and !=)
        jmp \1
.fail_\@:
    .endm
    
    .macro lbgts ; long branch if greater-than (signed)
        bmi .x_\@ ; don't jump if less-than
        beq .x_\@ ; don't jump if equal
        jmp \1
.x_\@:
    .endm
    
    .macro lbges ; long branch if greater-than-or-equal (signed)
        bmi .x_\@ ; don't jump if less-than
        jmp \1
.x_\@:
    .endm