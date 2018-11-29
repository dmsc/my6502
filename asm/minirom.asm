
        opt     f+h-l+

; TIMER registers:
TIMERL  = $FE00   ; TIMER low counter (R/W)
TIMERH  = $FE01   ; TIMER high coutner (R/W)
TIMERC  = $FE02   ; TIMER status (R), control (W)

; UART registers:
UARTD   = $FE20   ; UART RX data (R) , TX data (W)
UARTS   = $FE21   ; UART status (R) , clear flafs (W)

; LED Driver registers:
LEDDPWRR = $FE41   ; LED Driver Pulse Width Register for RED (W)
LEDDPWRG = $FE42   ; LED Driver Pulse Width Register for GREEN (W)
LEDDPWRB = $FE43   ; LED Driver Pulse Width Register for BLUE (W)

LEDDBCRR = $FE45   ; LED Driver Breathe On Control Register (W)
LEDDBCFR = $FE46   ; LED Driver Breathe Off Control Register (W)

LEDDCR0  = $FE48   ; LED Driver Control Register 0 (W)
LEDDBR   = $FE49   ; LED Driver Pre-scale Register (W)
LEDDONR  = $FE4A   ; LED Driver ON Time Register (W)
LEDDOFR  = $FE4B   ; LED Driver OFF Time Register (W)

ptr     = 0   // Use locations 0,1 as pointer
tmp     = 2


        org     $FF00

;----------------------------------------------------------------------
; Reads an HEX number, exits to prompt on error
get_hex .proc

        jsr     again
again:
        jsr     get_char
        eor     #'0'
        cmp     #10
        bcc     digit
        ora     #$20            ; Lower to upper case
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


;----------------------------------------------------------------------
; Reads a character, ignores control chars and spaces, echoes the
; character back. Exits to prompt on timeout.
get_char .proc

        ldx     #5              // Timeout: 2.5 seconds is app 250 * 60000 cycles

        // Init timer to 24000-2
t24000:
        stx     LEDDPWRG        // Show LED interaction
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
.def :exit_prompt
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

    .endp       ; Fall-through

put_char .proc
        bit     UARTS
        bmi     put_char
        sta     UARTD
        rts
    .endp       ; PROMPT bellow uses this "RTS" as '`':

prompt_msg = *-1
        .byte   10, 13

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
        bne put_char
    .endp

reset:
        cld
        sei

        // Print initial character
        lda     #'#'
        sta     UARTD

        // Test two bytes of ZP RAM
        asl     ; Use A = $46 (F) to signal error
        sta     ptr
        cmp     ptr
        bne     put_char

        asl     ; Use A = $8C to init LED control
        sta     LEDDCR0

        // Now test and fill all memory with 0
        ldx     #0
        stx     ptr
        stx     ptr+1

        // Init stack pointer
        dex     // X = $FF
        txs

        dex     // X = $FE, Fill up to $FDFF
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
        ldx     #2
prompt_loop:
        lda     prompt_msg,x
        jsr     put_char
        dex
        bpl     prompt_loop

        // Get command address: 2 bytes
        jsr     get_hex
        sta     ptr+1
        jsr     get_hex
        sta     ptr

        // Get command character
        jsr     get_char
        ldy     #0

        // ":" means "ENTER" 16 bytes
        cmp     #':'
        bne     not_enter

enter_loop:
        jsr     get_hex
        sta     (ptr), y
        iny
        cpy     #$10
        bne     enter_loop
        tya     ; Fall through next comparison with A=10, so it is false.

not_enter:
        // "S" means "SHOW" 16 bytes
        eor     #'S'
        bne     not_show

show_loop:
        lda     (ptr), y
        jsr     print_hex
        iny
        cpy     #$10
        bne     show_loop
        tya     ; Fall through next comparison with A=10, so it is false.

not_show:
        // "R" means "RUN" - EOR above menas "R" == 1
        lsr
        bne     prompt
        jmp     (ptr)


nmi = $200
irq = $203


        .echo   "Used: ", * - $FF00 + 6, " bytes, remains: ", $FFFA - *

        org     $FFFA
        .word   nmi

        org     $FFFC
        .word   reset

        org     $FFFE
        .word   irq

