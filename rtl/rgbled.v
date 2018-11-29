// RGB led driver for the 8 bit bus

module rgbled(
//  output [7:0] dbr,   // Data bus READ (UNUSED)
    input  [7:0] dbw,   // Data bus WRITE
    input  [3:0] addr,  // Address bus - two bits
    input  we,          // write/read
    input  rst,         // reset
    input  clk,         // Clock
    output RGB_R,       // I/O for RED led
    output RGB_G,       // I/O for GREEN led
    output RGB_B,       // I/O for BLUE led
    );

    wire pwm_red, pwm_green, pwm_blue;

    // Simply use iCE40 LEDDA block:
    SB_LEDDA_IP ledda_i (
        .LEDDCS(we),
        .LEDDCLK(clk),
        .LEDDDAT7(dbw[7]),
        .LEDDDAT6(dbw[6]),
        .LEDDDAT5(dbw[5]),
        .LEDDDAT4(dbw[4]),
        .LEDDDAT3(dbw[3]),
        .LEDDDAT2(dbw[2]),
        .LEDDDAT1(dbw[1]),
        .LEDDDAT0(dbw[0]),
        .LEDDADDR3(addr[3]),
        .LEDDADDR2(addr[2]),
        .LEDDADDR1(addr[1]),
        .LEDDADDR0(addr[0]),
        .LEDDDEN(we),
        .LEDDEXE(1),            // Always enabled
//        .LEDDRST(rst),        // Not supported by icestorm!
        .PWMOUT0(pwm_red),
        .PWMOUT1(pwm_green),
        .PWMOUT2(pwm_blue)
    );

    SB_RGBA_DRV #(
        .CURRENT_MODE("0b1"),
        .RGB0_CURRENT("0b000111"),
        .RGB1_CURRENT("0b000111"),
        .RGB2_CURRENT("0b000111")
    ) RGBA_DRIVER (
        .CURREN(1'b1),
        .RGBLEDEN(1'b1),
        .RGB0PWM(pwm_red),
        .RGB1PWM(pwm_green),
        .RGB2PWM(pwm_blue),
        .RGB0(RGB_R),
        .RGB1(RGB_G),
        .RGB2(RGB_B)
    );

endmodule

