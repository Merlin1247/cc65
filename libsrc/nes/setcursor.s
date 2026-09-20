;
; Written by Groepaz/Hitmen <groepaz@gmx.net>
; Cleanup by Ullrich von Bassewitz <uz@cc65.org>
; Rewritten by Brandon Woodward
;
; Set the cursor position and screen position

        .export         setcursor_pos, setcursor_posx, setcursor_screenptr

        .include        "nes.inc"

;-----------------------------------------------------------------------------

;y+(++x*32)+$2000
setcursor_pos:

        stx CURS_Y          ; Fallthrough

setcursor_posx:

        sty CURS_X          ; Fallthrough

.proc   setcursor_screenptr

        sty      SCREEN_PTR      ; Target val: --1000xx xxxyyyyy
        inx
        txa
        sec
        ror     a
        ror     a
        ror     a
        sta     SCREEN_PTR+1    ; Contains garbage in the most significant 2 bits
        and     #%11000000
        ROR     a
        adc     SCREEN_PTR
        sta     SCREEN_PTR
        rts

.endproc
