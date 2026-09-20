;
; Start-up code for cc65 (NES version)
;
; by Groepaz/Hitmen <groepaz@gmx.net>
; based on code by Ullrich von Bassewitz <uz@cc65.org>
; Optimizations, header update & bugfixes by Brandon Woodward
;

        .export         _exit
        .export         __STARTUP__ : absolute = 1      ; Mark as startup

        .import         initlib, donelib, callmain
        .import         push0, _main, zerobss, copydata
        .import         ppubuf_flush, paletteinit
        .import         clrscr_skipvsync

        ; Linker-generated symbols
        .import         __RAM_START__, __RAM_SIZE__
        .import         __SRAM_START__, __SRAM_SIZE__
        .import         __ROM0_START__, __ROM0_SIZE__
        .import         __STARTUP_LOAD__,__STARTUP_RUN__, __STARTUP_SIZE__
        .import         __CODE_LOAD__,__CODE_RUN__, __CODE_SIZE__
        .import         __RODATA_LOAD__,__RODATA_RUN__, __RODATA_SIZE__

; ------------------------------------------------------------------------
; Character data
; ------------------------------------------------------------------------
        .forceimport    NESfont

        .include        "zeropage.inc"
        .include        "nes.inc"


; ------------------------------------------------------------------------
; 16-byte NES2.0 header

.segment        "HEADER"

; For complete documentation, visit https://nesdev.org/wiki/NES_2.0

        .byte   $4E,$45,$53,$1a ; "NES"^Z
        .byte   2               ; PRG-ROM size in 16kb increments
        .byte   1               ; CHR-ROM size in 8kb increments
        .byte   %00000011       ; mirroring/battery flags & part of mapper number
        .byte   %00001000       ; mapper number, console type, NES2.0 identifier
        .byte   $00             ; mapper/submapper number
        .byte   $00             ; ROM size most significant bits
        .byte   $77             ; 8kb battery-backed WRAM
        .byte   $00             ; CHR-RAM size
        .byte   0, 0, 0, 0      ; Remaining fields unspecified

; ------------------------------------------------------------------------
; Place the startup code in a special segment.

.segment        "STARTUP"

start:

; Set up the CPU and PPU.

        sei
        cld
        ldx     #0
        stx     ppuctrl2_buf
        stx     PPU_CTRL2
        stx     PPU_CTRL1

        lda     PPU_STATUS       ; Clear the vblank flag if set
@wait1: lda     PPU_STATUS
        bpl     @wait1           ; Wait for VBLANK

; Reset regs

        stx     ppust_count
        stx     sprdma_en
        txs

; Reset OAM buffer

        lda #$FF
@spr:   sta oambuff, X
        inx
        bne @spr

; Clear the BSS data.

        jsr     zerobss

; Initialize the data.

        jsr     copydata

; Set up the stack.

        lda     #<(__SRAM_START__ + __SRAM_SIZE__)
        ldx     #>(__SRAM_START__ + __SRAM_SIZE__)
        sta     c_sp
        stx     c_sp+1          ; Set argument stack ptr

; Wait for VBLANK again (fixes issue #2989), PPU will be stable after this

@wait2: lda     PPU_STATUS
        bpl     @wait2          ; Wait for VBLANK again (fixes issue #)

; Update the palette while we're still in VBLANK

        jsr     paletteinit     ; Init palette while we're still in VBLANK

        lda     #$A0
        sta     PPU_CTRL1       ; Enable NMIs
        jsr     clrscr_skipvsync

; Call the module constructors.

        jsr     initlib

; Push the command-line arguments; and, call main().

        jsr     callmain

; Call the module destructors. This is also the exit() entry.

_exit:  jsr     donelib         ; Run module destructors

; Reset the NES.

        jmp start

; ------------------------------------------------------------------------
; System V-Blank Interrupt
; Updates PPU Memory (buffered).
; Updates VBLANK_FLAG and tickcount.
; ------------------------------------------------------------------------

nmi:    pha
        tya
        pha
        txa
        pha
; 
        ldy     ppust_count
        jmp     @st
@l:     lda     ppust_buff+$A0,y
        sta     PPU_VRAM_ADDR2
        lda     ppust_buff+$50,y
        sta     PPU_VRAM_ADDR2
        lda     ppust_buff+$00,y
        sta     PPU_VRAM_IO
@st:    dey
        bpl     @l
        iny                     ; Y = 0

; Read byte from VRAM if requested
        lda     ppuld_hi
        beq     @s1
        sta     PPU_VRAM_ADDR2
        lda     ppuld_lo
        sta     PPU_VRAM_ADDR2
        lda     PPU_VRAM_IO
        lda     PPU_VRAM_IO
        sta     ppuld_val
        sty     ppuld_hi
@s1:

; Reset scrolling.
        sty     PPU_VRAM_ADDR1
        sty     PPU_VRAM_ADDR1

; Reset nametable bits
        ldx     #$A0
        stx     PPU_CTRL1

; Apply rendering buffer
        lda     ppuctrl2_buf
        sta     PPU_CTRL2

; Do a sprite DMA if requested
        lda     sprdma_en
        bpl     @s2
        lda     #2
        sta     APU_SPR_DMA
        sta     sprdma_en
@s2:

        sty     ppust_count
        stx     VBLANK_FLAG     ; X != 0

        inc     tickcount
        bne     @s3
        inc     tickcount+1

@s3:    pla
        tax
        pla
        tay
        pla

; Interrupt exit

irq:
        rti


; ------------------------------------------------------------------------
; Hardware vectors
; ------------------------------------------------------------------------

.segment "VECTORS"

        .word   nmi         ; $fffa vblank nmi
        .word   start       ; $fffc reset
        .word   irq         ; $fffe irq / brk
