`timescale 1ns / 1ps
`default_nettype none

// Performs this calculation in 27 cycles... holy pipelining
module depth_calculator #(
    parameter LOG_D = 8
) (
    input wire clk,
    input wire [159:0] triangle, // color|p1x|p1y|p2x|p2y|p3x|p3y|P(24)|nx(8)|ny(8)|nz(8)
    input wire signed [10:0] x_coord,
    input wire signed [9:0] y_coord,
    output wire [15:0] depth
);

    logic signed [7:0] nx_in, ny_in, nz_in;
    assign nz_in = triangle[7:0];
    assign ny_in = triangle[15:8];
    assign nx_in = triangle[23:16];

    logic signed [23:0] P_in;
    assign P_in = triangle[47:24];

    //////////////////////////////////////////// Dot product calculation (10 cycles) /////////////////////////////////////////

    logic signed [18:0] nx_times_x, ny_times_y, nz_times_z;

    // small_multiplier x_mult(
    //     .clk(clk),
    //     .signed_11(x_coord),
    //     .signed_8(nx_in),
    //     .signed_output(nx_times_x)
    // );

    logic signed [18:0] x_dsp_multiplier;
    always_ff @( posedge clk ) begin
        x_dsp_multiplier <= $signed(x_coord) * nx_in;
    end

    pipeline #(.WIDTH(19), .STAGES_NEEDED(8)) nx_times_x_pl_inst (
        .clk(clk),
        .in(x_dsp_multiplier),
        .out(nx_times_x)
    );

    small_multiplier y_mult(
        .clk(clk),
        .signed_11({y_coord[9], y_coord}), // sign extend y_coord appropriately
        .signed_8(ny_in),
        .signed_output(ny_times_y)
    );

    logic signed [7:0] nz_int;
    pipeline #(.WIDTH(8), .STAGES_NEEDED(9)) nz_pipeline (
        .clk(clk),
        .in(nz_in),
        .out(nz_int)
    );
    logic signed [18:0] nz_int_resized;
    assign nz_int_resized = nz_int;
    assign nz_times_z = $signed(nz_int_resized) << LOG_D;


    logic signed [19:0] n_dot_pixel;
    always_ff @( posedge clk ) begin
        n_dot_pixel <= nx_times_x + ny_times_y + nz_times_z;
    end

    ///// P_in is 24

    logic signed [23:0] P_int;
    pipeline #(.WIDTH(24), .STAGES_NEEDED(10)) p_int (
        .clk(clk),
        .in(P_in),
        .out(P_int)
    );

    ////////////////////////////////////////////////// Division yikers (17) /////////////////////////////////////////////////
    
    logic [23:0] P_int_abs;
    assign P_int_abs = (P_int < 0) ? -P_int : P_int;

    logic [31:0] P_int_left_8;
    assign P_int_left_8 = P_int_abs << LOG_D;

    logic [31:0] P_int_2;
    logic [5:0] P_int_2_shift;
    logic [19:0] n_dot_pixel_int_2;
    always_ff @(posedge clk) begin
        P_int_2 <= P_int_left_8;

        n_dot_pixel_int_2 <= (n_dot_pixel < 0) ? -n_dot_pixel : n_dot_pixel;

        P_int_2_shift <= 0;
        for (int i = 31; i >= 16; i = i-1) begin
            if(P_int_left_8[i]) begin
                P_int_2_shift <= i - 15;
                break;
            end
        end
    end

    logic [15:0] dividend;
    assign dividend = P_int_2 >>> P_int_2_shift;
    logic [15:0] divisor;
    assign divisor = n_dot_pixel_int_2 >>> P_int_2_shift;

    divider3 #(.WIDTH(16)) dp_divider (
        .clk(clk),
        .rst(0),
        .dividend_in(dividend),
        .divisor_in(divisor),
        .data_valid_in(1),
        .quotient_out(depth),
        .remainder_out(),
        .data_valid_out(),
        .error_out(),
        .busy_out()
    );

    // P is 24 bits, which we will then bitshift left by LOG_D (8) to be 32 bits.
    // dividend is n_dot_pixel, 20 bits
    // Our divider is 16 bits LMFAO so we're going to have to truncate, depending on the largest pixel in n_dot_pixel.

    
    
endmodule

`default_nettype wire
