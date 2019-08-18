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

// Main system - connect data buses

module system(
    input  clk25,       // Main clock: 25.175MHz for VGA to work
    input  rst,         // reset
    output uart_tx,     // TX data bit
    input  uart_rx,     // RX data bit
    output led_r,       // LED RED
    output led_g,       // LED GREEN
    output led_b,       // LED BLUE
    inout spi0_mosi,    // SPI MOSI
    inout spi0_miso,    // SPI MISO
    inout spi0_sclk,    // SPI SCLK
    inout spi0_cs0,     // SPI CS0
    inout ps2_data,     // PS/2 DATA
    inout ps2_clock,    // PS/2 CLOCK
    output vga_h,       // VGA HSync
    output vga_v,       // VGA VSync
    output vga_r,       // VGA RED
    output vga_g,       // VGA GREEN
    output vga_b,       // VGA BLUE
    output vga_i        // VGA INTENSITY
    );

    parameter CLK_HZ = 115200*18; //app 2MHz

    wire [15:0] addr;
    wire [7:0] dbr;
    wire [7:0] dbw;
    wire we;
    wire irq = 0;
    wire nmi = 0;
    wire rdy = 1;
    wire [15:0] monitor;

    reg cpu_clk = 0;

    // Divide main clock for CPU:
    always @(posedge clk25)
    begin
        cpu_clk <= !cpu_clk;
    end

    cpu mycpu(
        .clk(cpu_clk),
        .reset(rst),
        .AB(addr),
        .DI(dbr),
        .DO(dbw),
        .WE(we),
        .IRQ(irq),
        .NMI(nmi),
        .RDY(rdy),
        .PC_MONITOR(monitor)
    );

    wire timer1_s, uart1_s, rom1_s, ram1_s, rgb1_s, spi1_s, psk1_s, vga1_s, vram1_s;
    assign timer1_s = (addr[15:5] == 11'b11111110000); // $FE00 - $FE1F
    assign uart1_s  = (addr[15:5] == 11'b11111110001); // $FE20 - $FE3F
    assign rgb1_s   = (addr[15:5] == 11'b11111110010); // $FE40 - $FE5F
    assign vga1_s   = (addr[15:5] == 11'b11111110011); // $FE60 - $FE7F
    assign spi1_s   = (addr[15:5] == 11'b11111110100); // $FE80 - $FE9F
    assign psk1_s   = (addr[15:5] == 11'b11111110101); // $FEA0 - $FEBF
    assign rom1_s   = (addr[15:8] ==  8'b11111111);    // $FF00 - $FFFF
    assign vram1_s  = (addr[15:12] == 4'b1101)         //
                   || (addr[15:12] == 4'b1110);        // $D000 - $EFFF
    assign ram1_s   = (addr[15:9] !=  7'b1111111)      // $0000 - $CFFF + $F000 - $FDFF
                   && (!vram1_s);                      //

    reg timer1_cs, uart1_cs, spi1_cs, psk1_cs, rom1_cs, ram1_cs, vram1_cs;
    always @(posedge cpu_clk or posedge rst)
    begin
        if (rst)
        begin
            timer1_cs <= 0;
            uart1_cs  <= 0;
            spi1_cs   <= 0;
            psk1_cs   <= 0;
            rom1_cs   <= 0;
            ram1_cs   <= 0;
            vram1_cs  <= 0;
        end
        else
        begin
            timer1_cs <= timer1_s;
            uart1_cs  <= uart1_s;
            spi1_cs   <= spi1_s;
            psk1_cs   <= psk1_s;
            rom1_cs   <= rom1_s;
            ram1_cs   <= ram1_s;
            vram1_cs  <= vram1_s;
        end
    end

    always @(posedge clk25 or posedge rst)
    begin
        if (rst)
        begin
            vram1_dbr <= 8'b0;
        end
        else if (cpu_clk == 0)
        begin
            vram1_dbr <= vram1_dbr_o;
        end
    end

    wire [7:0] timer1_dbr;
    wire [7:0] uart1_dbr;
    wire [7:0] spi1_dbr;
    wire [7:0] psk1_dbr;
    wire [7:0] rom1_dbr;
    wire [7:0] ram1_dbr;
    reg  [7:0] vram1_dbr;

    /* This synthesizes to more gates:
    assign dbr = timer1_cs ? timer1_dbr :
                 uart1_cs  ? uart1_dbr :
                 rom1_cs   ? rom1_dbr : 8'hFF;
    */

    assign dbr = (timer1_cs ? timer1_dbr : 8'hFF) &
                 (uart1_cs  ? uart1_dbr : 8'hFF) &
                 (spi1_cs   ? spi1_dbr : 8'hFF) &
                 (psk1_cs   ? psk1_dbr : 8'hFF) &
                 (rom1_cs   ? rom1_dbr : 8'hFF) &
                 (ram1_cs   ? ram1_dbr : 8'hFF) &
                 (vram1_cs  ? vram1_dbr : 8'hFF) ;

    timer timer1(
        .dbr(timer1_dbr),
        .dbw(dbw),
        .addr(addr[1:0]),
        .we(we & timer1_s),
        .rst(rst),
        .clk(cpu_clk)
    );

    uart #(
        .CLK_HZ(CLK_HZ/2)
    ) uart1 (
        .dbr(uart1_dbr),
        .dbw(dbw),
        .addr(addr[0:0]),
        .we(we & uart1_s),
        .rst(rst),
        .clk(cpu_clk),
        .tx(uart_tx),
        .rx(uart_rx)
    );

    minirom rom1(
        .dbr(rom1_dbr),
        .addr(addr[7:0]),
        .clk(cpu_clk)
    );

    // Video RAM is accessed at double rate, interleaving VGA and CPU
    wire [15:0] vga_addr;
    wire [7:0] vram1_dbr_o;

    wire [15:0] vmem_cpu_addr = { vga_page, !addr[12], addr[11:0] };
    wire [15:0] vram_addr = (cpu_clk == 1) ? vmem_cpu_addr : vga_addr;
    wire vram_we  = (cpu_clk == 1) ? we & vram1_s : 0;

    // Video RAM, mapped 8Kb at a time from $C000 to $DFFF
    ram vram1(
        .dbr(vram1_dbr_o),
        .dbw(dbw),
        .addr(vram_addr),
        .we(vram_we),
        .clk(clk25)
    );

    // Main CPU RAM, 64Kb mapped from $0000 to $FDFF
    ram ram1(
        .dbr(ram1_dbr),
        .dbw(dbw),
        .addr(addr),
        .we(we),
        .clk(cpu_clk)
    );

    wire [2:0] vga_page;
    vga vga1(
        .addr_out(vga_addr),
        .data_in(vram1_dbr_o),
        .clk(clk25),
        .cpu_clk(cpu_clk),
        .rst(rst),
        .cpu_addr(addr[2:0]),
        .cpu_dbw(dbw),
        .cpu_we(we & vga1_s),
        .vga_page(vga_page),
        .hsync(vga_h),
        .vsync(vga_v),
        .red(vga_r),
        .green(vga_g),
        .blue(vga_b),
        .intensity(vga_i)
    );

    wire led_r, led_g, led_b;
    rgbled rgb1(
//        .dbr(rgb_dbr),  // No data read. (UNUSED)
        .dbw(dbw),
        .addr(addr[3:0]),
        .we(we & rgb1_s),
        .rst(rst),
        .clk(cpu_clk),
        .RGB_R(led_r),
        .RGB_G(led_g),
        .RGB_B(led_b)
    );

    spi_flash spi1(
        .dbr(spi1_dbr),
        .dbw(dbw),
        .addr(addr[3:0]),
        .we(we & spi1_s),
        .rst(rst),
        .clk(cpu_clk),
        // I/O pins:
        .spi_mosi(spi0_mosi),
        .spi_miso(spi0_miso),
        .spi_sclk(spi0_sclk),
        .spi_cs0(spi0_cs0)
    );

    ps2_kbd psk1(
        .dbr(psk1_dbr),
        .dbw(dbw),
        .addr(addr[0]),
        .we(we & psk1_s),
        .rst(rst),
        .clk(cpu_clk),
        // I/O pins:
        .ps2_data(ps2_data),
        .ps2_clock(ps2_clock)
    );
endmodule

