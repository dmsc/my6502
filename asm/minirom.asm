
        opt     f+h-l+

UARTD = $FE20
UARTS = $FE21
TIMERL = $FE00
TIMERH = $FE01
TIMERC = $FE02

charout .macro
wait    bit     UARTS
        bmi     wait
        sta     UARTD
        .endm

        org     $FF00

reset:
        cld
        sei

        // Print welcome message via serial port
msg_loop:
        lda     message, x
        charout
        inx
        cpx     #msg_len
        bne     msg_loop

        // Reset timer
        ldy     #0
        sty     TIMERC

        // Wait for characters from serial port, print "." once each second
second:
        lda     #'.'
        charout
        tya
        iny
        and     #$0F
        clc
        adc     #$41
        charout
        lda     #$0D
        charout
        lda     #$0A
        charout

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

message:
        .byte   'Hello from my 6502!', 13, 10
msg_len = * - message

nmi:
irq:
        rti



        org     $FFFA
        .word   nmi

        org     $FFFC
        .word   reset

        org     $FFFE
        .word   irq

