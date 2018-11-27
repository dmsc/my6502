
        opt     f+h-l+

UARTD = $FE20
UARTS = $FE21
TIMERL = $FE00
TIMERH = $FE01
TIMERC = $FE02

ptr     = 0   // Use locations 0,1 as pointer
tmp     = 2


        org     $FF00

print_hex:
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
put_char:
        bit     UARTS
        bmi     put_char
        sta     UARTD
        rts

reset:
        cld
        sei

        // Print initial character
        lda     #'+'
        sta     UARTD

        // Init stack pointer
        ldx     #$FF
        txs

        // Test two bytes of ZP RAM
        lda     #'Z'
        sta     ptr
        cmp     ptr
        bne     put_char

        // Now test and fill all memory with 0
        dex             // $FE = Fill up to $FDFF
        lda     #0
        sta     ptr
        sta     ptr+1
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
        ldx     ptr+1
        lda     #'E'
        cpx     #2
        bcc     put_char
        // Print amount of ram
        txa
        jsr     print_hex

        // Prompt and process commands
prompt:
        lda     #13
        jsr     put_char
        lda     #10
        jsr     put_char
        lda     #'>'
        jsr     put_char

        // Get command address: 2 bytes
        jsr     get_hex
        sta     ptr+1
        jsr     get_hex
        sta     ptr

        // Get command character
        jsr     get_char
        ldy     #0

        // "R" means "RUN"
        cmp     #'R'
        bne     not_run
        jmp     (ptr)

not_run:
        // ":" means "ENTER" 16 bytes
        cmp     #':'
        bne     not_enter

enter_loop:
        jsr     get_hex
        sta     (ptr), y
        iny
        cpy     #$10
        bne     enter_loop
        beq     prompt

not_enter:
        // "S" means "SHOW" 16 bytes
        cmp     #'S'
        bne     prompt

show_loop:
        lda     (ptr), y
        jsr     print_hex
        iny
        cpy     #$10
        bne     show_loop
        beq     prompt

        // Wait for characters from serial port, print "." once each second
get_char:
        ldx     #5              // Timeout: 2.5 seconds is app 250 * 60000 cycles

        // Init timer to 24000-2
t24000:
        lda     #$E9    // Optimization: use $E9E9 for timer reload, giving $E9EB cycles
        sta     TIMERL
        sta     TIMERH
        lda     #1
        sta     TIMERC  // Start timer

        // Check if we need to keep waiting
        inx
        bne     wait

        // Timeout, stop timer and go to prompt
        stx     TIMERC
exit_prompt:
        pla
        pla
        jmp     prompt

        // Wait for timer or uart receive
wait:
        lda     TIMERC
        bmi     t24000
        bit     UARTS
        bvc     wait

        dec     TIMERC  // Stop timer
        // Ok, we have a character, return it
        lda     UARTD
        sta     UARTS
        cmp     #'!'
        bcc     get_char
        jsr     put_char
        rts

get_hex .proc

        jsr     again
again:
        jsr     get_char
        eor     #'0'
        cmp     #10
        bcc     digit
        adc     #$88
        cmp     #$FA
        bcc     exit_prompt     ; Not an hex number
digit:
        sec
        rol
        asl
        asl
        asl
        asl
rloop:
        rol     tmp
        asl
        bne     rloop
        lda     tmp
        rts

        .endp

nmi = $200
irq = $203


        .echo   "Used: ", * - $FF00 + 6, " bytes, remains: ", $FFFA - *

        org     $FFFA
        .word   nmi

        org     $FFFC
        .word   reset

        org     $FFFE
        .word   irq

