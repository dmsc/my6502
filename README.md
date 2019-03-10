Simple 6502 computer for ice40up5k FPGA.
----------------------------------------

This is the verilog source for a very simple 6502 based computer with the
following hardware:

- 6502 CPU, using Arlet Ottens core.
- A reloadable 16 bit timer module, at address $FE00.
- An UART at fixed 115200 baud rate, at address $FE20.
- An RGB led controller (with PWM, ramps and On/Off times), at address $FE40.
- 256 bytes of boot ROM at address $FF00 to $FFFF.
- 63.5k bytes of RAM, at address $0000 to $FDFF.
- VGA output with memory mapped bitmap, 320x204 pixels, at address $C000 to $DFFF.

The implementation was tested with an Upduino board, this is a cheap (US$10)
board with an ice40-up5k FPGA chip.

See the file rtl/upduino.pcf for the current pinout.

