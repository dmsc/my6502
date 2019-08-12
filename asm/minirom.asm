
        opt     f+h-l+

; TIMER registers:
TIMERL  = $FE00   ; TIMER low counter (R/W)
TIMERH  = $FE01   ; TIMER high counter (R/W)
TIMERC  = $FE02   ; TIMER status (R), control (W)

; UART registers:
UARTD   = $FE20   ; UART RX data (R) , TX data (W)
UARTS   = $FE21   ; UART status (R) , clear flags (W)

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

; VGA registers
VGAPAGE  = $FE60   ; VGA access page
VGAMODE  = $FE61   ; VGA graphics mode
                   ; Bits 0-1 : Mode for each line,
                   ;            00 = TEXT, 01 = HI_RES, 10 = HI_COLOR, 11 = LOW_RES
                   ; Bits 3-7 : Height of each line in pixels - 1.
VGAGBASE = $FE62   ; VGA graphics bitmap address, 2 bytes.
VGACBASE = $FE64   ; VGA color memory address, 2 bytes
VGAFBASE = $FE66   ; VGA font page - 1 byte.

; VGA memory window
VIDEOMEM = $D000   ; Video memory window - 8kB from $D000 to $EFFF.


ptr     = 0   // Use locations 0,1 as pointer
tmp     = 2


        org     $FF00

prompt_msg = *
        .byte   '?', 10, 13

;----------------------------------------------------------------------
; Reads an HEX number, exits to prompt on error
get_hex .proc

        jsr     get_low_hex
        asl
        asl
        asl
        asl
        sta     tmp
get_low_hex:
        jsr     get_char
        eor     #'0'            ; Transform '0'-'9' to 0-9
        cmp     #10             ; Check if digit...
        bcc     digit           ; ...and accept.
        ora     #$20            ; Lower to upper case
        sbc     #'A'^'0'        ; Transform 'A'-'F' to 0-5
        cmp     #$06            ; Check if 'A' to 'F'...
        bcs     prompt          ; ...not an hex number, reject
        adc     #$0A            ; Fix to 10-15.
digit:
        ora     tmp
        rts
    .endp

;----------------------------------------------------------------------
; Reads a character, ignores control chars and spaces, echoes the
; character back. Exits to prompt on timeout.
get_char .proc

        // Wait for uart receive
wait:
        bit     UARTS
        bvc     wait

        // Ok, we have a character, return it
        lda     UARTD
        sta     UARTS
        cmp     #'!'    ; Ignore spaces and control characters.
        bcc     wait

    .endp       ; Fall-through

put_char .proc
        bit     UARTS
        bmi     put_char
        sta     UARTD
        rts
    .endp

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
        beq     ok_ram1
        sta     UARTD
ok_ram1:

        asl     ; Use A = $8C to init LED control
        sta     LEDDCR0


        // Now test and fill all memory with 0
        lda     #0
        sta     ptr
        sta     ptr+1

        dex     // X = $FE, Fill up to $FDFF
        tay
clrmem
        sta     (ptr), y
        cmp     (ptr), y
        bne     prompt // Can't change, end of RAM
        iny
        bne     clrmem
        inc     ptr+1
        cpx     ptr+1
        bne     clrmem

        // Prompt and process commands
prompt:
        // Init stack pointer
        ldx     #$FF
        txs
        ldy     #3

prompt_loop:
        lda     prompt_msg-1,y
        jsr     put_char
        dey
        bne     prompt_loop
        // Here, Y = 0

        // Get command address: 2 bytes
        jsr     get_hex
        sta     ptr+1
        jsr     get_hex
        sta     ptr

        // Get command character
        jsr     get_char

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
        ora     #$20    ; make uppercase -> lowercase
        // "S" means "SHOW" 16 bytes
        eor     #'s'
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
        jsr     call_prog
        jmp     prompt
call_prog:
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

