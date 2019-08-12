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
    input [2:0] cpu_addr, // CPU address for write to registers
    input [7:0] cpu_dbw,  // CPU data bus write
    input  cpu_we,        // CPU write enable
    output [2:0] vga_page,// CPU access page to video RAM
    output hsync,
    output vsync,
    output reg red,
    output reg green,
    output reg blue,
    output reg intensity,
    output reg [15:0] addr_out,
    input [7:0] data_in
    );

    parameter CLK_HZ = 25175000; // 25.175MHz

    parameter HMODE_TEXT  = 2'b00;
    parameter HMODE_HIRES = 2'b01;
    parameter HMODE_HICLR = 2'b10;
    parameter HMODE_LORES = 2'b11;

    // Implement VGA registers:
    //  00 : bits 2-0: VGA access page
    //       bits 7-3: line height - 1
    reg [2:0] vga_page;
    //  01 : bits 1-0: Video Mode
    //       bits 7-3: line height - 1
    reg [1:0] hv_mode;
    reg [4:0] pix_height;
    //  02 : bitmap base, low
    //  03 : bitmap base, hi
    reg [15:0] bitmap_base;
    //  04 : color base, low
    //  05 : color base, hi
    reg [15:0] color_base;
    //  06 : font base, hi
    reg [7:0] font_base;
    always @(posedge cpu_clk or posedge rst)
    begin
        if (rst)
        begin
            vga_page   <= 0;
            hv_mode    <= HMODE_TEXT;
            pix_height <= 15;
            bitmap_base <=    0;
            color_base  <= 4096;
            font_base   <= 32;
        end
        else if( cpu_we )
        begin
            case (cpu_addr)
                3'b000:
                begin
                    vga_page <= cpu_dbw[2:0];
                end
                3'b001:
                begin
                    hv_mode    <= cpu_dbw[1:0];
                    pix_height <= cpu_dbw[7:3];
                end
                3'b010:
                begin
                    bitmap_base[7:0] <= cpu_dbw;
                end
                3'b011:
                begin
                    bitmap_base[15:8] <= cpu_dbw;
                end
                3'b100:
                begin
                    color_base[7:0] <= cpu_dbw;
                end
                3'b101:
                begin
                    color_base[15:8] <= cpu_dbw;
                end
                3'b110:
                begin
                    font_base <= cpu_dbw;
                end
            endcase
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
    localparam HSP_CLK =  48;   //  96: Sync pulse end, start of back porch
    localparam HBP_CLK =  72;   // 144: Back porch end, start of visible area
    localparam HVA_CLK = 392;   // 784: Visible area end, start of front porch
    localparam HFP_CLK = 400;   // 800: Front porch end, end of full line.

    localparam HC_W = $clog2(HFP_CLK); // Horizontal Counter width
    reg [HC_W-1:0] hcount;

    wire h_end = (cpu_clk == 1) && (hcount == (HFP_CLK-1));
    always @(posedge clk or posedge rst)
    begin
        if (rst)
            hcount <= 0;
        else if(cpu_clk == 1)
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
    localparam VBP_CLK =  35;     // Back porch end, start of visible area
    localparam VVA_CLK = 515;     // Visible area end, start of front porch
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

    // Active area: output image
    wire vactive = ((vcount >= VBP_CLK) && (vcount < VVA_CLK)) ? 1 : 0;
    wire hactive = ((hcount >= HBP_CLK) && (hcount < HVA_CLK)) ? 1 : 0;
    wire hactive_prev = ((hcount >= (HBP_CLK-3)) && (hcount < (HVA_CLK-3))) ? 1 : 0;

    // Output data
    reg [7:0] bitmap_data;
    reg [7:0] color_data;
    reg [7:0] data_sr;

    // Memory counters:
    reg [4:0] font_line;    // Font line: 0 - 31
    reg [7:0] column_addr;  // Column byte: 0 - 255
    reg [11:0] bitmap_line; // Bitmap line: 0 - 4095 (*8)

    // Video data
    always @(posedge clk)
    begin
        // Copy memory read data to internal register
        // we can read memory only when CPU clock is 1.
        if (cpu_clk == 1)
        begin
            // DMA state machine - reads memory depending on current
            // graphics mode.
            //
            // We have 800 pixel clocks per line, half those are DMA clocks,
            // so we have 400 DMA clocks per line.
            //
            // Clock   0 -  47 : Sync pulse
            // Clock  48 -  71 : Back porch
            // Clock  72 - 391 : Visible area
            // Clock 392 - 399 : Front porch
            //
            // 00: TEXT MODE (80):
            //   80 bytes char data
            //   80 bytes color data
            //   80 bytes bitmap data (from font address)
            //
            //   Per each 8 pixels in a character (4 DMA clocks):
            //    0 : -
            //    1 : Read BITMAP (char) into font address
            //    2 : Read FONT into output data
            //    3 : Read COLOR into next_color
            //
            // 01: HI_RES MODE (640, 1-bpp):
            //   80 bytes color data
            //   80 bytes bitmap data
            //
            //   Per each 8 pixels (4 DMA clocks):
            //    0 : -
            //    1 : Read BITMAP into output data
            //    2 : -
            //    3 : Read COLOR into next_color
            //
            // 10: HI_COLOR MODE (320, 4-bpp):
            //   160 bytes bitmap data
            //
            //   Per each 8 pixels (4 DMA clocks):
            //    0 : Read BITMAP into output data
            //    1 : Read BITMAP into output data
            //    2 : -
            //    3 : -
            //
            // 11: LOW_RES MODE (320, 1-bpp):
            //   40 bytes bitmap data
            //
            //   Per each 16 pixels (8 DMA clocks):
            //    0 : -
            //    1 : -
            //    2 : -
            //    3 : -
            //    4 : -
            //    5 : Read BITMAP into output data
            //    6 : -
            //    7 : Read COLOR into next_color
            case (hcount[1:0])
                2'b00:
                begin
                    bitmap_data <= data_in; // Only used in HI color mode
                    addr_out <= { bitmap_base + {bitmap_line, 3'b000} + column_addr };
                end
                2'b01:
                begin
                    bitmap_data <= data_in;
                    addr_out <= { {font_base, data_in} + {font_line, 8'd0} };
                end
                2'b10:
                begin
                    if (hv_mode == HMODE_TEXT)
                        bitmap_data <= data_in;
                    addr_out <= { color_base + {bitmap_line, 3'b000} + column_addr };
                end
                2'b11:
                begin
                    color_data <= data_in;
                    // Address is 1 more than current, as we will read data of next cell.
                    addr_out <= { bitmap_base + {bitmap_line, 3'b001} + column_addr };
                end
            endcase
        end
        // Handle address counters - only during visible part of screen
        if (hactive_prev)
        begin
            if ((hcount[1:0] == 2'b11) && (cpu_clk == 1))
            begin
                // Increment pointers:
                if (hv_mode == HMODE_LORES)
                begin
                    if( hcount[2] == 1 )
                        column_addr <= column_addr + 1;
                end
                else if (hv_mode == HMODE_HICLR)
                    column_addr <= column_addr + 2;
                else
                    column_addr <= column_addr + 1;
            end
        end
        else
        begin
            // Reset column address
            column_addr <= 0;
            // And once per line, increment pointers
            if(h_end)
            begin
                if (!vactive)
                begin
                    font_line <= 0;
                    bitmap_line <= 0;
                end
                else if (font_line == pix_height)
                    // Increase line addresses after "pix_height" lines
                begin
                    font_line <= 0;
                    if (hv_mode == HMODE_HICLR)
                        bitmap_line <= bitmap_line + (160/8);
                    else if (hv_mode == HMODE_HIRES || hv_mode == HMODE_TEXT)
                        bitmap_line <= bitmap_line + (80/8);
                    else
                        bitmap_line <= bitmap_line + (40/8);
                end
                else
                    font_line <= font_line + 1;
            end
        end

        // Shift data
        if(hv_mode == HMODE_LORES)
        begin
            if ((hcount[2:0] == 3'b111) && (cpu_clk == 1))
                data_sr <= bitmap_data;               // Read from memory
            else if (cpu_clk == 1)
                data_sr  <= { 1'b0, data_sr[7:1] };   // Shift data
        end
        else if (hv_mode == HMODE_HICLR)
        begin
            if ((hcount[0] == 1) && (cpu_clk == 1))
                data_sr <= bitmap_data;               // Read from memory (2 pixels)
        end
        else // HIRES and TEXT
        begin
            if ((hcount[1:0] == 2'b11) && (cpu_clk == 1))
                data_sr <= bitmap_data;               // Read from memory
            else
                data_sr  <= { 1'b0, data_sr[7:1] };   // Shift data
        end

        // Video output
        if (vactive && hactive)
        begin
            if (hv_mode == HMODE_LORES)
            begin
                red       = data_sr[0] ? color_data[0] : color_data[4];
                green     = data_sr[0] ? color_data[1] : color_data[5];
                blue      = data_sr[0] ? color_data[2] : color_data[6];
                intensity = data_sr[0] ? color_data[3] : color_data[7];
            end
            else if (hv_mode == HMODE_HIRES || hv_mode == HMODE_TEXT)
            begin
                red       = data_sr[0] ? color_data[0] : color_data[4];
                green     = data_sr[0] ? color_data[1] : color_data[5];
                blue      = data_sr[0] ? color_data[2] : color_data[6];
                intensity = data_sr[0] ? color_data[3] : color_data[7];
            end
            else if (hv_mode == HMODE_HICLR)
            begin
                if (hcount[0] == 0)
                begin
                    red       = data_sr[0];
                    green     = data_sr[1];
                    blue      = data_sr[2];
                    intensity = data_sr[3];
                end
                else
                begin
                    red       = data_sr[4];
                    green     = data_sr[5];
                    blue      = data_sr[6];
                    intensity = data_sr[7];
                end
            end
        end
        else
        begin
            red       = 0;
            green     = 0;
            blue      = 0;
            intensity = 0;
        end
    end

endmodule

