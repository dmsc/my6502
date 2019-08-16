; my6502 register definitions
; ---------------------------

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

; SPI registers
SPI_CTRL  = $FE80  ; SPI control register, any write stops the transaction
                   ;  (CS goes high, bus is tristated)
SPI_STAT  = $FE80  ; SPI status register:
                   ;  Bit 7: trnsmission pending.
                   ;  Bit 6: togles each received byte available.
                   ;  Bit 0: CS state (1 = SPI disabled, 0 = enabled).
SPI_WRITE = $FE81  ; SPI write, a write starts a SPI transsaction, byte is
                   ;  copied to the hold register and will transmit after
                   ;  current one ends.
SPI_READ  = $FE81  ; SPI read, reads data in the reception hold register.
                   ;  after each byte trasmited.

; SPI transfer routines in ROM:
SPI_LOAD   = $FFD0      ; Address of SPI load routine. Reads 256 bytes
                        ; from flash to the SPI_BUFFER address.
                        ; On input, A/X is the sector to read from FLASH
SPI_BUFFER = 0          ; Use locations 0,1 as pointer to SPI buffer

