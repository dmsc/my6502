// A simple UART for an 8 bit bus

module uart(
    output reg [7:0] dbr,   // Data bus READ
    input  [7:0] dbw,   // Data bus WRITE
    input  [0:0] addr,  // Address bus - only one bit
    input  we,          // write/read
    input  rst,         // reset
    input  clk,         // Clock
    output reg tx,      // TX data bit
    input  rx           // RX data bit
    );

    parameter CLK_HZ = 115200*5; //25000000; // Master clock: 25MHz
    parameter BAUD = 115200;

    localparam RX_DIVISOR = CLK_HZ / (2 * BAUD) - 1;    // Our divisor
    localparam RX_W = $clog2(RX_DIVISOR+1);             // Clock generator width

    localparam TX_DIVISOR = CLK_HZ / BAUD - 1;  // Our divisor
    localparam TX_W = $clog2(TX_DIVISOR+1);     // Clock generator width

    // Internal registers
    reg [8:0] tx_next; // Next byte to transmit plus stop bit
    reg [7:0] tx_crnt; // Current byte being transmitted - copied from tx_next on idle
    reg [3:0] state;   // State: 0 == idle, 10 to 1 = transmitting
    wire tx_active = |state;
    wire chip_write = we;

    // TX baud-rate generator
    reg [TX_W-1:0] tx_count = 0;
    wire tx_bit = (tx_count == TX_DIVISOR);
    always @(posedge clk or posedge rst)
    begin
        if (rst)
            tx_count <= 0;
        else
            tx_count <= (tx_bit | !tx_active) ? 0 : (tx_count+1);
    end

    // TX state machine
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            state <= 0;
            tx <= 1;
            tx_crnt <= 0;
            tx_next <= 9'b000000000;
            dbr <= 0;
        end
        else
        begin
            // Process writes to registers
            if (chip_write)
            begin
                if (addr[0] == 1'b0)
                begin
                    // TODO: signal overrun (tx_next[8] == 1)
                    tx_next <= { 1'b1, dbw };
                end
            end
            else // chip_read
            begin
                if (addr == 1'b1)
                    dbr <= { tx_next[8], 7'b0 };
                else
                    dbr <= 0;
            end

            // Main processing
            if (tx_active)
            begin
                if (tx_bit)
                begin
                    { tx_crnt, tx } <= { 1'b1, tx_crnt }; // Shift one bit to output
                    state <= state - 1;
                end
            end
            else if (tx_next[8] == 1)
            begin
                { tx_crnt, tx } <= { tx_next[7:0] , 1'b0 };// Shift start bit and next byte
                tx_next[8] <= 0;
                state <= 10;
            end
        end
    end

endmodule
