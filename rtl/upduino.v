// ICE40UP implementation details

module upduino(
    input  uart_rx,
    output uart_tx,
    output clk_1,
    output clk_2
    );

    wire clk;

    // Main clock : 48/8 = 6MHz
    SB_HFOSC #(
        .CLKHF_DIV("0b11")
    ) hfosc (
        .CLKHFEN(1'b1),
        .CLKHFPU(1'b1),
        .CLKHF(clk)
    );

    system #(
        .CLK_HZ(6000000)
    ) sys1 (
        .clk(clk),
        .rst(reset),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx)
    );

    reg [3:0] cdiv = 4'b0;
    reg reset = 1;
    always @(posedge clk)
    begin
        cdiv <= cdiv + 1;
        if(cdiv == 4'b1111)
            reset <= 0;
    end

    assign clk_1 = reset;
    assign clk_2 = cdiv[3];

endmodule

