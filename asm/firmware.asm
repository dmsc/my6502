
        opt     f+h-l+

        icl     "defines.inc"

snum = 2
ptr  = 4

        org     $10
scr_color       .ds     1
scr_col         .ds     1
scr_row         .ds     1
scr_tptr        .ds     2
scr_cptr        .ds     2
scr_escape      .ds     1

        org     $200

        ; Main rom jumps here on load:
start:
        ; Load rest of boot program from $201 to $21f in memory $300 to $21FF
        lda     #$03
        sta     SPI_BUFFER+1
        lda     #0
        sta     SPI_BUFFER
        lda     #$01    ; Sector $201
        ldx     #$02
        ldy     #$1F    ; Number of sectors
        jsr     load_sectors

        ; Load the font from sectors $220 to $23F
        lda     #$01
        sta     VGAPAGE
        lda     #$D0
        sta     SPI_BUFFER+1
        lda     #$20    ; Sector $220
        ldx     #$02
        ldy     #$20    ; Number of sectors
        jsr     load_sectors
        lda     #$00
        sta     VGAPAGE

        ; Clear screen
        jsr     screen_init

        ldy     #0

msg_loop
        lda     message, y
        beq     end_msg
        iny
        sty     ptr
        jsr     screen_putchar
        ldy     ptr
        bne     msg_loop
end_msg

char_loop:
        bit     PS2_STAT
        bpl     char_loop

        // Ok, we have a character, return it
        lda     PS2_DATA
        sta     PS2_CTRL

        ldx     #$2F
        bvc     k_press
        ldx     #$4F
k_press stx     scr_color

        pha

        jsr     print_hex

        ldx     #$1F
        stx     scr_color
        lda     #' '
        jsr     screen_putchar

        pla
        cmp     #$76
        beq     ret1
        jmp     char_loop

        ; end....
ret1:   rts

print_hex .proc
        pha
        lsr
        lsr
        lsr
        lsr
        jsr     hex_digit
        pla
        and     #$0F
hex_digit:
        sed			; set decimal mode
	cmp	#$0A		; set carry for +1 if >9
	adc	#'0'		; add ASCII "0"
	cld			; clear decimal mode
        jmp     screen_putchar
    .endp

message:
        .byte 'my6502 Computer - (c) 2019 dmsc', 10
:31     .byte 205
        .byte 10
        .byte 0

load_sectors:
        sty     snum+2
        stx     snum+1
        sta     snum
next_sector:
        lda     snum
        ldx     snum+1
        jsr     SPI_LOAD
        inc     SPI_BUFFER+1
        inc     snum
        bne     no_inc
        inc     snum+1
no_inc:
        dec     snum+2
        bne     next_sector
        rts


        ; boot sector signature:
        org     $2FE
        .byte   $FF, $00


        org     $300

scroll:
        lda     #$d0
        jsr     scroll_mem
        lda     #$e0
scroll_mem
        sta     scr_tptr+1
        sta     scr_cptr+1
        lda     #0
        sta     scr_cptr
        lda     #80
        sta     scr_tptr
        ldx     #30

copy_line
        ldy     #79
cl_loop
        lda     (scr_tptr), y
        sta     (scr_cptr), y
        dey
        bpl     cl_loop
        lda     scr_tptr
        sta     scr_cptr
        clc
        adc     #80
        sta     scr_tptr
        lda     scr_tptr+1
        sta     scr_cptr+1
        adc     #0
        sta     scr_tptr+1
        dex
        bne     copy_line
        rts

        ; Main program
screen_init:
        lda     #0
        sta     VGAPAGE
        sta     VGAGBASE
        sta     VGAGBASE+1
        sta     VGACBASE
        lda     #$10
        sta     VGACBASE+1
        lda     #$20
        sta     VGAFBASE
        lda     #$78
        sta     VGAMODE
        lda     #$1F
        sta     scr_color
screen_clear:
        lda     #0
        sta     scr_col
        sta     scr_row
        sta     scr_tptr
        sta     scr_cptr
        lda     #$D9
        sta     scr_tptr+1
        lda     #$E9
        sta     scr_cptr+1
        ldy     #96+79
        ldx     scr_color

clear_loop:
        lda     #' '
        sta     (scr_tptr), y
        txa
        sta     (scr_cptr), y
        dey
        cpy     #255
        bne     clear_loop
        dec     scr_tptr+1
        dec     scr_cptr+1
        lda     scr_tptr+1
        cmp     #$d0
        bcs     clear_loop
        rts

set_escape:
        ror     scr_escape
ret:    rts

backspace:
        lda     scr_col
        beq     ret
        dec     scr_col
        jsr     calc_address
        lda     #' '
        sta     (scr_tptr), y
        bne     set_cursor

scr_linefeed:
        lda     #0
        sta     scr_col
        ldx     scr_row
        inx
        cpx     #30
        bcc     no_scroll
        ldy     #0
        lda     scr_color
        sta     (scr_cptr), y
        jsr     scroll
        ldx     #29
no_scroll
        stx     scr_row
        jsr     calc_address
        jmp     set_cursor

screen_putchar:
        ; Control characters (most are TODO yet)
        ;  07 = BEL
        ;  08 = BS
        ;  09 = TAB
        ;  0a = EOL
        ;  1a = CLEAR
        ;  1b = ESC
        ;  1c = UP
        ;  1d = DOWN
        ;  1e = LEFT
        ;  1f = RIGHT
        bit     scr_escape
        bmi     no_control
        cmp     #$1b
        beq     set_escape
        cmp     #$1a
        beq     screen_clear
        cmp     #$08
        beq     backspace
        cmp     #$0A
        beq     scr_linefeed

no_control
        pha     ; Save character
        jsr     calc_address
        pla

        sta     (scr_tptr), y
        lda     scr_color
        sta     (scr_cptr), y

        lda     scr_col
        cmp     #79
        bcs     scr_linefeed

        inc     scr_tptr
        inc     scr_cptr
        bne     inc1
        inc     scr_tptr+1
        inc     scr_cptr+1
inc1
        inc     scr_col

        sty     scr_escape

set_cursor
        lda     scr_color
        asl
        adc     #$80
        rol
        asl
        adc     #$80
        rol
        sta     (scr_cptr), y
        rts

calc_address
        ; Clear cursor
        ldy     #0
        lda     scr_color
        sta     (scr_cptr), y

        lda     #$D
        sta     scr_tptr+1

        lda     scr_row

        asl             ; max =  60
        asl             ; max = 120
        adc     scr_row ; max = 145
        asl             ; max = 290
        rol     scr_tptr+1
        asl             ; max = 580
        rol     scr_tptr+1
        asl             ; max = 1160
        rol     scr_tptr+1
        asl             ; max = 2320
        rol     scr_tptr+1

        adc     scr_col ; max = 2399
        sta     scr_tptr
        sta     scr_cptr
        lda     scr_tptr+1
        adc     #0
        sta     scr_tptr+1
        adc     #$10
        sta     scr_cptr+1
        rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Keyboard handler

        ; Now the font data in ROM
        org     $2200
        ins     "cp850-16.font"

