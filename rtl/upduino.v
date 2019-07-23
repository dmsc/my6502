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

// ICE40UP implementation details

module upduino(
    input  uart_rx,
    output uart_tx,
    output led_r,
    output led_g,
    output led_b,
    output vga_h,
    output vga_v,
    output vga_r,
    output vga_g,
    output vga_b,
    output vga_i,
    input  iclk
    );

    wire clk25;
    wire lock;

    // Main clock from PLL
    pll pll1(
        .clock_in(iclk),
        .clock_out(clk25),
        .locked(lock)
    );

    system #(
        .CLK_HZ(25175000)
    ) sys1 (
        .clk25(clk25),
        .rst(reset),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .led_r(led_r),
        .led_g(led_g),
        .led_b(led_b),
        .vga_h(vga_h),
        .vga_v(vga_v),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_i(vga_i)
    );

    reg [3:0] cdiv = 4'b0;
    reg reset = 1;
    always @(posedge clk25)
    begin
        if (lock)
        begin
            cdiv <= cdiv + 1;
            if(cdiv == 4'b1111)
                reset <= 0;
        end
    end

endmodule

