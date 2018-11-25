
        opt     f+h-l+

UARTD = $FE20
UARTS = $FE21
TIMERL = $FE00
TIMERH = $FE01
TIMERC = $FE02

ptr     = 0   // Use locations 0,1 as pointer

charout .macro
wait    bit     UARTS
        bmi     wait
        sta     UARTD
        .endm

        org     $FF00

reset:
        cld
        sei

        // Print initial character
        lda     #'+'
        charout

        // Test two bytes of ZP RAM
        lda     #$55
        ldx     #$AA
        sta     ptr
        stx     ptr+1
        cmp     ptr
        bne     bad_zp
        cpx     ptr+1
        bne     bad_zp
        asl     ptr
        lsr     ptr+1
        cpx     ptr
        bne     bad_zp
        cmp     ptr+1
        bne     bad_zp

        // Now test and fill all memory with 0
        lda     #0
        sta     ptr
        sta     ptr+1
        ldx     #$FE    // Fill up to $FDFF
        ldy     #ptr+2  // From ptr+2

clrmem
        lda     #$55
        sta     (ptr), y
        cmp     0
        beq     end_ram // We changed location 0, so we reached RAM limit
        eor     (ptr), y
        bne     end_ram // Or we could not change location, also end of RAM
        sta     (ptr), y
        cmp     (ptr), y
        bne     end_ram // Also can't change, end of RAM
        iny
        bne     clrmem
        inc     ptr+1
        cpx     ptr+1
        bne     clrmem

end_ram:
        // Check if we have at least 512 bytes of RAM
        lda     1
        lsr
        beq     bad_ram

        // Print welcome message
        jsr     ok

        // Reset timer
        ldy     #0
        sty     TIMERC

        // Wait for characters from serial port, print "." once each second
second:
        ldx     #(msg_dot - messages)
        jsr     msg_loop

        ldx     #250    // One second is 250 * 24000 cycles

        // Init timer to 24000
t24000:
        lda     #<24000
        sta     TIMERL
        lda     #>24000
        sta     TIMERH
        lda     #1
        sta     TIMERC

        // Check if we need to keep waiting
        dex
        beq     second

        // Wait for timer or uart receive
wait:
        lda     TIMERC
        bmi     t24000
        bit     UARTS
        bvc     wait

        // Write te character through the serial port
        sta     UARTS
        lda     UARTD
        charout
        jmp     wait

bad_zp:
        ldx     #(msg_bad_zp - messages)
        bne     msg_loop

bad_ram:
        ldx     #(msg_bad_ram - messages)
        bne     msg_loop
ok:
        ldx     #(msg_ok - messages)
msg_loop:
        lda     messages, x
        charout
        inx
        cmp     #10
        bne     msg_loop
        rts

print_hex:

messages:

msg_ok:
        .byte   'Welcome to my6502', 13, 10

msg_bad_zp:
        .byte   'ZP '

msg_bad_ram:
        .byte 'mem error!', 13, 10

msg_dot:
        .byte   '.', 13, 10

nmi:
irq:
        rti



        org     $FFFA
        .word   nmi

        org     $FFFC
        .word   reset

        org     $FFFE
        .word   irq

