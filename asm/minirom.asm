
        opt     f+h-l+

UARTD = $FE20
UARTS = $FE21
TIMERL = $FE00
TIMERH = $FE01
TIMERC = $FE02

        org     $FF00

reset:
        cld
        sei

        // Print a message via serial port, repeated via a timer
        lda     #0
        sta     TIMERC

again:
        lda     #<5000
        sta     TIMERL
        lda     #>5000
        sta     TIMERH
        sec
        rol     TIMERC

        ldx     #0

msg_loop:
        lda     message, x
//        jsr     charout

charout1:
        bit     UARTS
        bmi     charout1
        sta     UARTD

        inx
        cpx     #msg_len
        bne     msg_loop

        // Now, use the timer to wait 10000 counts
wait:
        lda     TIMERC
        bpl     wait
        jmp     again

message:
        .byte   'Hello from my 6502!', 13, 10
msg_len = * - message

charout:
        bit     UARTS
        bmi     charout
        sta     UARTD
        rts


nmi:
irq:
        rti



        org     $FFFA
        .word   nmi

        org     $FFFC
        .word   reset

        org     $FFFE
        .word   irq

