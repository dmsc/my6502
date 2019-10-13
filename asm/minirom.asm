
        opt     f+h-l+

        icl     "defines.inc"

tmp     = 2
ptr     = 0


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
        cli

        // Print initial character
        lda     #'#'

        // Test one byte of ZP RAM
        sta     ptr
        cmp     ptr
        beq     ok_ram1
        asl     // Transform '#' ($23) to 'F' ($46)
ok_ram1:
        sta     UARTD

        // Clear from $0000 to $01FB, avoids clearing the stack!
        ldx     #1
        stx     ptr+1
        lda     #0
        sta     ptr
        ldy     #$FB
clear_loop
        sta     (ptr), y
        dey
        bne     clear_loop
        dec     ptr+1
        bpl     clear_loop

        ; Read from flash sector $200 to address $200
        ; ( A already zero from above )
        ldx     #2
        stx     ptr+1
        jsr     read_sector

        ; Check if the ROM is valid and jump to the address
        lda     SIGNATURE_ADDR
        bne     prompt
        ldx     SIGNATURE_ADDR+1
        inx
        bne     prompt
        jsr     BOOT_START

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

write_spi:
        bit     SPI_CTRL
        bmi     write_spi
        sta     SPI_WRITE
        rts

        .echo   "Used: ", * - $FF00, " bytes, remains: ", SPI_LOAD - *

        org    SPI_LOAD
        ; Read from sector in AX to (ptr)
read_sector:
        ldy     #$03
        sty     SPI_WRITE       // Command - start SPI transaction
        stx     SPI_WRITE       // Address [23:16]
        jsr     write_spi       // Address [15:8]
        lda     #0
        jsr     write_spi       // Address [7:0]
        jsr     write_spi       // Dummy transfer to read data
        tay
        nop
spi_loop:
        stx     SPI_WRITE       // Start dummy transfer
        lda     SPI_READ        // Read from previous dummy
        sta     (SPI_BUFFER), y
        iny
        bne     spi_loop
        sty     SPI_CTRL
        rts

call_prog:
        jmp     (ptr)

        .echo   "Used: ", * - SPI_LOAD, " bytes, remains: ", $FFFA - *

        org     $FFFA
        .word   NMI_VECTOR

        org     $FFFC
        .word   reset

        org     $FFFE
        .word   IRQ_VECTOR

