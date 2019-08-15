/*
 * Simple 6502 computer for ice40up5k FPGA.
 *
 * (C) Daniel Serpell, <daniel.serpell@gmail.com>
 *
 * Feel free to use this code in any project (commercial or not), as long as you
 * keep this message, and the copyright notice. This code is provided "as is",
 * without any warranties of any kind.
 *
 */

// SPI flash interface

module spi_flash (
    output reg [7:0] dbr,   // Data bus READ
    input  [7:0] dbw,   // Data bus WRITE
    input  [3:0] addr,  // Address bus - 16 registers
    input  we,          // write
    input  rst,         // reset
    input  clk,         // Clock
    inout  spi_mosi,    // External pin MOSI
    inout  spi_miso,    // External pin MISO
    inout  spi_sclk,    // External pin SCLK
    inout  spi_cs0      // External pin CS
    );

    wire chip_write = we;


    wire miso_in;
    wire mosi_out;
    wire mosi_oe;
    wire sclk_out, sclk_oe;
    wire cs0_out, cs0_oe;

    reg gen_clk;
    reg gen_cs;
    reg tx_hold;
    reg [2:0] tx_bit;
    reg [7:0] tx_data;
    reg [7:0] tx_shift;
    reg rx_valid;
    reg [7:0] rx_data;
    reg [7:0] rx_shift;

    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            gen_cs  <= 1;
            gen_clk <= 1;
            tx_hold <= 0;
            tx_bit <= 0;
            tx_data <= 0;
            tx_shift <= 0;
            rx_valid <= 0;
            rx_data <= 0;
            rx_shift <= 0;
        end
        else
        begin
            if (gen_clk == 0) // SCLK positive edge
            begin
                // Raise clock, we shift data in
                gen_clk <= 1;
                rx_shift <= { rx_shift[6:0], miso_in };
                if( (tx_bit == 0) )
                begin
                    rx_valid <= !rx_valid;
                    rx_data <= { rx_shift[6:0], miso_in };
                end
            end
            else              // SCLK negative edge
            begin
                if ( tx_hold || (tx_bit != 0) )
                begin
                    gen_cs  <= 0;       // Lower CS and clock
                    gen_clk <= 0;
                    if ( tx_bit == 0 )
                    begin
                        tx_hold <= 0;
                        tx_shift <= tx_data;
                        tx_bit <= 7;
                    end
                    else
                    begin
                        tx_shift <= { tx_shift[6:0], 1'b0 };
                        tx_bit <= tx_bit - 1;
                    end
                end
            end

            // Process writes to registers
            if (chip_write)
            begin
                case(addr)
                    2'b00: begin gen_cs <= 1; gen_clk <= 1;  end
                    2'b01: begin tx_data <= dbw; tx_hold <= 1; end
                endcase
            end
            else
            begin
                case(addr)
                    2'b00: dbr <= { tx_hold, rx_valid, 5'b0, gen_cs };
                    2'b01: dbr <= rx_data;
                endcase
            end
        end
    end

    // In default state, all outputs are tri-stated, this
    // allows other devices to access the FLASH.
    assign cs0_oe  = !gen_cs;
    assign sclk_oe = !gen_cs;
    assign mosi_oe = !gen_cs;
    // The chip select is 0 when we are in transfer
    assign cs0_out = gen_cs;
    // Our output clock is the same as the CPU clock
    assign sclk_out = gen_clk;
    // MOSI output from transmitter shift register
    assign mosi_out = tx_shift[7];

    // I/O drivers are tri-state output w/ simple input
    // MOSI driver
    SB_IO #(
        .PIN_TYPE(6'b101001),   // Simple input pin (D_IN_0) and tristate output
        .PULLUP(1'b1),          // Active pull-up
        .NEG_TRIGGER(1'b0),     // Standard trigger (rising edge)
        .IO_STANDARD("SB_LVCMOS")
    ) io_mosi (
        .PACKAGE_PIN(spi_mosi),
        .LATCH_INPUT_VALUE(1'b0),
        .CLOCK_ENABLE(1'b0),
        .INPUT_CLK(1'b0),
        .OUTPUT_CLK(1'b0),
        .OUTPUT_ENABLE(mosi_oe),
        .D_OUT_0(mosi_out),
        .D_OUT_1(1'b0),
        .D_IN_0(),
        .D_IN_1()
    );

    // MISO input
    SB_IO #(
        .PIN_TYPE(6'b000001),   // Simple input pin (D_IN_0), no output
        .PULLUP(1'b1),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) io_miso (
        .PACKAGE_PIN(spi_miso),
        .LATCH_INPUT_VALUE(1'b0),
        .CLOCK_ENABLE(1'b0),
        .INPUT_CLK(1'b0),
        .OUTPUT_CLK(1'b0),
        .OUTPUT_ENABLE(1'b0),
        .D_OUT_0(1'b0),
        .D_OUT_1(1'b0),
        .D_IN_0(miso_in),
        .D_IN_1()
    );

    // SCK driver
    SB_IO #(
        .PIN_TYPE(6'b101001),   // Simple input pin (D_IN_0) and tristate output
        .PULLUP(1'b1),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) io_sclk (
        .PACKAGE_PIN(spi_sclk),
        .LATCH_INPUT_VALUE(1'b0),
        .CLOCK_ENABLE(1'b0),
        .INPUT_CLK(1'b0),
        .OUTPUT_CLK(1'b0),
        .OUTPUT_ENABLE(sclk_oe),
        .D_OUT_0(sclk_out),
        .D_OUT_1(1'b0),
        .D_IN_0(),
        .D_IN_1()
    );

    // CS0 driver
    SB_IO #(
        .PIN_TYPE(6'b101001),   // Simple input pin (D_IN_0) and tristate output
        .PULLUP(1'b1),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) io_cs0 (
        .PACKAGE_PIN(spi_cs0),
        .LATCH_INPUT_VALUE(1'b0),
        .CLOCK_ENABLE(1'b0),
        .INPUT_CLK(1'b0),
        .OUTPUT_CLK(1'b0),
        .OUTPUT_ENABLE(cs0_oe),
        .D_OUT_0(cs0_out),
        .D_OUT_1(1'b0),
        .D_IN_0(),
        .D_IN_1()
    );
endmodule

