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

// Very-simple Graphics Adapter

module vga(
    input  clk,         // Main clock
    input  cpu_clk,     // CPU clock to manage interleave
    input  rst,
    input [1:0] cpu_addr, // CPU address for write to registers
    input [7:0] cpu_dbw,  // CPU data bus write
    input  cpu_we,        // CPU write enable
    output hsync,
    output vsync,
    output reg red,
    output reg green,
    output reg blue,
    output reg intensity,
    output [12:0] addr_out,
    input [7:0] data_in
    );

    parameter CLK_HZ = 25175000; // 25.175MHz

    // Implement VGA registers:
    //  00 : Background and Foreground colors (4 bit each)
    reg [3:0] fore_color;
    reg [3:0] back_color;
    always @(posedge cpu_clk or posedge rst)
    begin
        if (rst)
        begin
            fore_color <= 4'hF;
            back_color <= 4'h0;
        end
        else if( cpu_we )
        begin
            if( cpu_addr == 2'b00 )
            begin
                fore_color <= cpu_dbw[3:0];
                back_color <= cpu_dbw[7:4];
            end
        end
    end


    // VGA video timings, from microseconds to clocks:
    //
    //  640x480 (0x7e) 25.175MHz -HSync -VSync
    //    h: width   640 start  656 end  752 total  800 skew    0 clock  31.47KHz
    //    v: height  480 start  490 end  492 total  525           clock  59.94Hz
    //  Standard: 25.175MHz:
    //   SP =   96 clocks:   0 ->  95 - Sync pulse
    //   BP =   48 clocks:  96 -> 143 - Back porch
    //   VA =  640 clocks: 144 -> 783 - Visible area
    //   FP =   16 clocks: 784 -> 799 - Front Porch
    //
    //   Total 800 clocks per line
    //
    // HSync is generated when clock count < SP.
    //
    localparam HSP_CLK =  96;   //  96: Sync pulse end, start of back porch
    localparam HBP_CLK = 144;   // 144: Back porch end, start of visible area
    localparam HVA_CLK = 784;   // 784: Visible area end, start of front porch
    localparam HFP_CLK = 800;   // 800: Front porch end, end of full line.

    localparam HC_W = $clog2(HFP_CLK); // Horizontal Counter width
    reg [HC_W-1:0] hcount;

    wire h_end = (hcount == (HFP_CLK-1));
    always @(posedge clk or posedge rst)
    begin
        if (rst)
            hcount <= 0;
        else
            hcount <= h_end ? 0 : (hcount+1);
    end

    // Vertical counters:
    //   SP =    2 lines:   0 ->   1 - Sync pulse
    //   BP =   32 lines:   2 ->  33 - Back porch
    //   VA =  480 lines:  34 -> 513 - Visible area
    //   FP =   10 lines: 514 -> 523 - Front Porch
    //
    //   Total 524 lines per frame.
    localparam VSP_CLK =   2;     // Sync pulse end, start of back porch
    localparam VBP_CLK =  35+36;  // Back porch end, start of visible area
    localparam VVA_CLK = 515-36;  // Visible area end, start of front porch
    localparam VFP_CLK = 525;     // Front porch end, end of full line.

    localparam VC_W = $clog2(VFP_CLK); // Vertical Counter width
    reg [VC_W-1:0] vcount;

    wire v_end = (vcount == (VFP_CLK-1));
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            vcount <= 0;
        end
        else if (h_end)
        begin
            vcount <= v_end ? 0 : (vcount+1);
        end
    end

    // Video generation: sync pulses
    assign hsync = (hcount < HSP_CLK) ? 0 : 1;
    assign vsync = (vcount < VSP_CLK) ? 0 : 1;

    always @(*)
    begin
        if (vactive && hactive )
        begin
            red       = data_bw[0] ? fore_color[0] : back_color[0];
            green     = data_bw[0] ? fore_color[1] : back_color[1];
            blue      = data_bw[0] ? fore_color[2] : back_color[2];
            intensity = data_bw[0] ? fore_color[3] : back_color[3];
        end
        else
        begin
            red       = 0;
            green     = 0;
            blue      = 0;
            intensity = 0;
        end
    end

    // Memory counters:
    reg [9:0] line_addr; // Address of current line, missing low addresses
    // Always update read address from line pointers
    wire [5:0] col_addr = (hcount>>4) - (HBP_CLK>>4) + 1;
    assign addr_out = (line_addr<<3) + col_addr;

    // Active area: output image
    wire vactive = ((vcount >= VBP_CLK) && (vcount < VVA_CLK)) ? 1 : 0;
    wire hactive = ((hcount >= HBP_CLK) && (hcount < HVA_CLK)) ? 1 : 0;

    // Output data
    reg [7:0] mdata_in;
    reg [7:0] data_bw;

    // Video data
    always @(posedge clk)
    begin
        // Copy memory read data to internal register
        if (cpu_clk == 1)
            mdata_in <= data_in;

        if (vactive)
        begin
            // On each line, we read from memory to internal buffer and
            // then outputs data
            if (hcount[3:0] == 4'b1111)
            begin
                // Read from memory
                data_bw <= mdata_in;
            end
            else if (hcount[0] == 1)
            begin
                data_bw  <= { 1'b0, data_bw[7:1] };
            end
            if (h_end && !vcount[0])
                line_addr <= line_addr + 5;
        end
        else
        begin
            // Reset address on inactive area
            line_addr <= 0;
        end
    end

endmodule

