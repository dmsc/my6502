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

    wire timer1_s, uart1_s, rom1_s;
    assign timer1_s = (addr[15:5] == 11'b11111110000); // $FE00 - $FE0F
    assign uart1_s  = (addr[15:5] == 11'b11111110001); // $FE20 - $FE2F
    assign rom1_s   = (addr[15:8] ==  8'hFF);          // $FF00 - $FFFF

    reg timer1_cs, uart1_cs, rom1_cs;
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            timer1_cs <= 0;
            uart1_cs  <= 0;
            rom1_cs   <= 0;
        end
        else
        begin
            timer1_cs <= timer1_s;
            uart1_cs  <= uart1_s;
            rom1_cs   <= rom1_s;
        end
    end

    wire [7:0] timer1_dbr;
    wire [7:0] uart1_dbr;
    wire [7:0] rom1_dbr;

    /* This synthesizes to more gates:
    assign dbr = timer1_cs ? timer1_dbr :
                 uart1_cs  ? uart1_dbr :
                 rom1_cs   ? rom1_dbr : 8'hFF;
    */

    assign dbr = (timer1_cs ? timer1_dbr : 8'hFF) &
                 (uart1_cs  ? uart1_dbr : 8'hFF) &
                 (rom1_cs   ? rom1_dbr : 8'hFF) ;

    timer timer1(
        .dbr(timer1_dbr),
        .dbw(dbw),
        .addr(addr[1:0]),
        .we(we & timer1_s),
        .rst(rst),
        .clk(clk)
    );

    uart #(
        .CLK_HZ(115200*9)
    ) uart1 (
        .dbr(uart1_dbr),
        .dbw(dbw),
        .addr(addr[0:0]),
        .we(we & uart1_s),
        .rst(rst),
        .clk(clk),
        .tx(uart_tx),
        .rx(uart_rx)
    );

    minirom rom1(
        .dbr(rom1_dbr),
        .addr(addr[7:0]),
        .clk(clk)
    );

endmodule

