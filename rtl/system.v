// Main system - connect data buses

module system(
    input  clk,         // Main clock
    input  rst,         // reset
    output uart_tx,     // TX data bit
    input  uart_rx      // RX data bit
    );

    wire [15:0] addr;
    wire [7:0] dbr;
    wire [7:0] dbw;
    wire we;
    wire irq = 0;
    wire nmi = 0;
    wire rdy = 1;
    wire [15:0] monitor;

    cpu mycpu(
        .clk(clk),
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

    reg timer1_cs, uart1_cs, rom1_cs, we_cs;
    reg [15:0] addr_c;

    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            addr_c    <= 0;
            timer1_cs <= 0;
            uart1_cs  <= 0;
            rom1_cs   <= 0;
            we_cs     <= 0;
        end
        else
        begin
            addr_c    <= addr;
            timer1_cs <= (addr[15:5] == 11'b11111110000); // $FE00 - $FE0F
            uart1_cs  <= (addr[15:5] == 11'b11111110001); // $FE20 - $FE2F
            rom1_cs   <= (addr[15:8] ==  8'hFF);   // $FF00 - $FFFF
            we_cs     <= we;
        end
    end

    wire [7:0] timer1_dbr;
    wire [7:0] uart1_dbr;
    wire [7:0] rom1_dbr;

    assign dbr = timer1_cs ? timer1_dbr :
                 uart1_cs  ? uart1_dbr :
                 rom1_cs   ? rom1_dbr : 8'bx;

    timer timer1(
        .dbr(timer1_dbr),
        .dbw(dbw),
        .addr(addr_c[1:0]),
        .cs(timer1_cs),
        .we(we_cs),
        .rst(rst),
        .clk(~clk)
    );

    uart #(
        .CLK_HZ(345600)
    ) uart1 (
        .dbr(uart1_dbr),
        .dbw(dbw),
        .addr(addr_c[0:0]),
        .cs(uart1_cs),
        .we(we_cs),
        .rst(rst),
        .clk(~clk),
        .tx(uart_tx),
        .rx(uart_rx)
    );

    minirom rom1(
        .dbr(rom1_dbr),
        .addr(addr_c[7:0]),
        .cs(rom1_cs),
        .clk(~clk)
    );

endmodule

