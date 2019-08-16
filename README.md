Simple 6502 computer for ice40up5k FPGA.
----------------------------------------

This is the verilog source for a very simple 6502 based computer with the
following hardware:

- 6502 CPU, using Arlet Ottens core.
- A reloadable 16 bit timer module, at address $FE00.
- An UART at fixed 115200 baud rate, at address $FE20.
- An RGB led controller (with PWM, ramps and On/Off times), at address $FE40.
- VGA video controller, registers at address $FE60.
- 64k bytes of VGA memory, 640x480 video with 4 graphics modes:
  - 16 color, 320x480 (or 320x240, 320x160, etc.) pixels, two pixels per byte.
  - 2 color, 640x480 (or 640x240, etc.) pixels, 8 pixels per two bytes, one byte bitmap data and one byte fore/back color.
  - 2 color, 320x480 (or 320x240, 320x160, etc.), 8 pixels per two bytes, one byte bitmap data and one byte fore/back color.
  - 2 color text mode, 80 characters of arbitrary height from 8x2 to 8x32, one byte character, one byte fore/back color, font in RAM.
- A simple SPI controller capable of reading and writing to the configuration FLASH, used as non-volatile storage. Currently the SPI clock is half the CPU clock, the code is capable of reading one byte from FLASH each 19 CPU cycles, about 660Kbyte/sec.
- All graphics modes support arbitrary memory start and height, font can be at any location.
- 256 bytes of boot ROM at address $FF00 to $FFFF.
- 63.5k bytes of RAM, at address $0000 to $FDFF.

The video controller runs at 25.13MHz to generate the video signal, the 6502 CPU runs at half that (12.56MHz), so the video controller access the VRAM in even cycles and the CPU at odd cycles, this allows sharing the bus without conflicts.

The implementation was tested with an Upduino board, this is a cheap (US$10)
board with an ice40-up5k FPGA chip.

You need to supply a 12MHz clock to pin 35, the on-chip PLL is used to raise this to 25.13MHz.

See the file rtl/upduino.pcf for the current pinout.

To generate the VGA levels, a simple 8 resistor divider is used:

    FPGA                             MONITOR

    (42)--RED-----------[470]--,------ R
                               |
                     .--[680]--'
                     |
    (36)--GREEN------)--[470]--,------ G
                     |         |
                     +--[680]--'
                     |
    (36)--BLUE-------)--[470]--,------ B
                     |         |
                     +--[680]--'
                     |
    (34)--INTENSITY--'

The above circuit approximates the 16 CGA colors, by generating 0.28V, 0.41V and 0.7V, this is 40%, 60% and 100% of each component. The following table shows the approximate colors:

| Index | IRGB | R | G | B |                          |
|-------|------|---|---|---|--------------------------|
|   0   | 0000 | 0 | 0 | 0 |![0](/doc/00.png?raw=true)|
|   1   | 0001 | 0 | 0 |150|![0](/doc/01.png?raw=true)|
|   2   | 0010 | 0 |150| 0 |![0](/doc/02.png?raw=true)|
|   3   | 0011 | 0 |150|150|![0](/doc/03.png?raw=true)|
|   4   | 0100 |150| 0 | 0 |![0](/doc/04.png?raw=true)|
|   5   | 0101 |150| 0 |150|![0](/doc/05.png?raw=true)|
|   6   | 0110 |150|150| 0 |![0](/doc/06.png?raw=true)|
|   7   | 0111 |150|150|150|![0](/doc/07.png?raw=true)|
|   8   | 1000 |104|104|104|![0](/doc/08.png?raw=true)|
|   9   | 1001 |104|104|255|![0](/doc/09.png?raw=true)|
|  10   | 1010 |104|255|104|![0](/doc/10.png?raw=true)|
|  11   | 1011 |104|255|255|![0](/doc/11.png?raw=true)|
|  12   | 1100 |255|104|104|![0](/doc/12.png?raw=true)|
|  13   | 1101 |255|104|255|![0](/doc/13.png?raw=true)|
|  14   | 1110 |255|255|104|![0](/doc/14.png?raw=true)|
|  15   | 1111 |255|255|255|![0](/doc/15.png?raw=true)|


