; Tells the MMC3 about what area to switch out.
REG_MMC3_SELECT = $8000
MMC3_SELECT_2K_CHR_00 = $00
MMC3_SELECT_2K_CHR_08 = $01
MMC3_SELECT_1K_CHR_10 = $02
MMC3_SELECT_1K_CHR_14 = $03
MMC3_SELECT_1K_CHR_18 = $04
MMC3_SELECT_1K_CHR_1C = $05
MMC3_SELECT_8K_PRG_80 = $06
MMC3_SELECT_8K_PRG_A0 = $07
MMC3_CHR_FLAG_SWAP = $80
; New bank to switch to, based on last value written to REG_MMC3_SELECT
; Either the position of an 8kb prg rom bank, or a 1kb or 1kb chr rom bank
REG_MMC3_DATA = $8001

; Nametable Mirroring
REG_MMC3_MIRROR = $A000
MMC3_MIRROR_VERTICAL = $00
MMC3_MIRROR_HORIZONTAL = $01

; PRG RAM controller
REG_MMC3_PRGRAM = $A001
MMC3_PRGRAM_ENABLE = $80
MMC3_PRGRAM_NOWRITE = $40

; This register specifies the IRQ counter reload value.
; When the IRQ counter is zero (or a reload is requested through $C001),
; this value will be copied into the MMC3 IRQ counter at
; the end of the current scanline
REG_MMC3_IRQ_LATCH = $C000
; Writing any value to this register clears the MMC3 IRQ counter
; so that it will be reloaded at the end of the current scanline.
REG_MMC3_IRQ_RELOAD = $C001
; Writing any value to this register will disable MMC3 interrupts
; AND acknowledge any pending interrupts.
REG_MMC3_IRQ_DISABLE = $E000
; Writing any value to this register will enable MMC3 interrupts.
REG_MMC3_IRQ_ENABLE = $E001

; Subroutine to switch a PRG or CHR ROM bank.
; t0 = value to write in REG_MMC3_SELECT
; t1 = value to write in REG_MMC3_DATA
;
; Careful:
; if this is changing PRG ROM, make sure that you're not
; calling the switch on a bank that you're executing from.
; To be extra safe, only switch from fixed-location code.
MMC3SwitchBank:
    lda t0
    sta REG_MMC3_SELECT
    lda t1
    sta REG_MMC3_DATA
    rts  