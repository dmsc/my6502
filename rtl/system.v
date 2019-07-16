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
    output vga_h,       // VGA HSync
    output vga_v,       // VGA VSync
    output vga_r,       // VGA RED
    output vga_g,       // VGA GREEN
    output vga_b        // VGA BLUE
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

    wire timer1_s, uart1_s, rom1_s, ram1_s, rgb1_s;
    assign timer1_s = (addr[15:5] == 11'b11111110000); // $FE00 - $FE0F
    assign uart1_s  = (addr[15:5] == 11'b11111110001); // $FE20 - $FE2F
    assign rgb1_s   = (addr[15:5] == 11'b11111110010); // $FE40 - $FE4F
    assign rom1_s   = (addr[15:8] ==  8'hFF);          // $FF00 - $FFFF
    assign ram1_s   = ((&(addr[15:9])) ==  0);         // $0000 - $FDFF

    reg timer1_cs, uart1_cs, rom1_cs, ram1_cs;
    always @(posedge cpu_clk or posedge rst)
    begin
        if (rst)
        begin
            timer1_cs <= 0;
            uart1_cs  <= 0;
            rom1_cs   <= 0;
            ram1_cs   <= 0;
        end
        else
        begin
            timer1_cs <= timer1_s;
            uart1_cs  <= uart1_s;
            rom1_cs   <= rom1_s;
            ram1_cs   <= ram1_s;
        end
    end

    wire [7:0] timer1_dbr;
    wire [7:0] uart1_dbr;
    wire [7:0] rom1_dbr;
    wire [7:0] ram1_dbr;

    /* This synthesizes to more gates:
    assign dbr = timer1_cs ? timer1_dbr :
                 uart1_cs  ? uart1_dbr :
                 rom1_cs   ? rom1_dbr : 8'hFF;
    */

    assign dbr = (timer1_cs ? timer1_dbr : 8'hFF) &
                 (uart1_cs  ? uart1_dbr : 8'hFF) &
                 (rom1_cs   ? rom1_dbr : 8'hFF) &
                 (ram1_cs   ? ram1_dbr : 8'hFF) ;

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

    // RAM is accessed at double rate, interleaving VGA and CPU
    wire [12:0] vga_addr;
    wire [7:0] ram1_dbr_o;

    wire [15:0] ram_addr = (cpu_clk == 1) ? addr : { 3'b110, vga_addr };
    wire ram_we  = (cpu_clk == 1) ? we & ram1_s : 0;

    reg [7:0] ram1_dbr_l;

    // Latch RAM data to the CPU clock.
    always @(posedge cpu_clk)
    begin
        ram1_dbr_l <= ram1_dbr_o;
    end
    assign ram1_dbr = ram1_dbr_l;

    ram ram1(
        .dbr(ram1_dbr_o),
        .dbw(dbw),
        .addr(ram_addr[15:0]),
        .we(ram_we),
        .clk(clk25)
    );

    vga vga1(
        .addr_out(vga_addr),
        .data_in(ram1_dbr_o),
        .clk(clk25),
        .cpu_clk(cpu_clk),
        .rst(rst),
        .hsync(vga_h),
        .vsync(vga_v),
        .red(vga_r),
        .green(vga_g),
        .blue(vga_b)
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

endmodule

