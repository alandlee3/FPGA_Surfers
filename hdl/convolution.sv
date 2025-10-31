`timescale 1ns / 1ps
`default_nettype none


module convolution #(
    parameter KERNEL_DIMENSION = 3,
    parameter K_SELECT = 0
    )(
    input wire clk,
    input wire rst,
    input wire [KERNEL_DIMENSION-1:0][15:0] data_in,
    input wire [10:0] h_count_in,
    input wire [9:0] v_count_in,
    input wire data_in_valid,
    output logic data_out_valid,
    output logic [10:0] h_count_out,
    output logic [9:0] v_count_out,
    output logic [15:0] line_out
    );

    // Your code here!

    /* Note that the coeffs output of the kernels module
     * is packed in all dimensions, so coeffs should be
     * defined as `logic signed [2:0][2:0][7:0] coeffs`
     *
     * This is because iVerilog seems to be weird about passing
     * signals between modules that are unpacked in more
     * than one dimension - even though this is perfectly
     * fine Verilog.
     */

     logic [2:0][2:0][15:0] cache;

     logic signed [2:0][2:0][10:0] red_cache;
     logic signed [2:0][2:0][10:0] green_cache;
     logic signed [2:0][2:0][10:0] blue_cache;
     logic signed [2:0][2:0][7:0] coeffs;
     logic signed [7:0] shift;

     logic [1:0][10:0] h_buff;
     logic [1:0][9:0] v_buff;
     logic [1:0] dout_buff;

    // intermediate values (after multiplying by coeffs)
     logic signed [2:0][2:0][10:0] red_interm;
     logic signed [2:0][2:0][10:0] green_interm;
     logic signed [2:0][2:0][10:0] blue_interm;

     logic signed [10:0] red_out;
     logic signed [10:0] green_out;
     logic signed [10:0] blue_out;

     logic [4:0] red_out_us;
     logic [5:0] green_out_us;
     logic [4:0] blue_out_us;

     always_comb begin
        // extra green, blue, red SIGNED caches
        for (int i =0; i < 3; i = i+1) begin
            for (int j = 0; j< 3; j=j+1) begin
                red_cache[i][j] = $signed({5'b0,cache[i][j][15:11]});
                green_cache[i][j] = $signed({4'b0,cache[i][j][10:5]});
                blue_cache[i][j] = $signed({5'b0,cache[i][j][4:0]});
            end
        end

        red_out_us = (red_out[10] == 1) ? 0 : (red_out[9:5] >= 1) ? 31 : red_out[4:0];
        green_out_us = (green_out[10] == 1) ? 0 : (green_out[9:6] >= 1) ? 63 : green_out[5:0];
        blue_out_us = (blue_out[10] == 1) ? 0 : (blue_out[9:5] >= 1) ? 31 : blue_out[4:0];
        line_out = {red_out_us, green_out_us, blue_out_us};
     end

     always_ff @(posedge clk) begin
        // load new values in for next cycle
        if (data_in_valid) begin
            for (int i =0; i < 3; i = i+1) begin
                cache[i][2] <= cache[i][1];
                cache[i][1] <= cache[i][0];
                cache[i][0] <= data_in[i];
            end
        end

        h_count_out <= h_buff[1];
        h_buff[1] <= h_buff[0];
        h_buff[0] <= h_count_in;
        v_count_out <= v_buff[1];
        v_buff[1] <= v_buff[0];
        v_buff[0] <= v_count_in;
        data_out_valid <= dout_buff[1];
        dout_buff[1] <= dout_buff[0];
        dout_buff[0] <= data_in_valid;
        
        for (int i =0; i < 3; i = i+1) begin
            for (int j = 0; j< 3; j=j+1) begin
                red_interm[i][j] <= $signed(red_cache[i][j]) * $signed(coeffs[i][j]);
                green_interm[i][j] <= $signed(green_cache[i][j]) * $signed(coeffs[i][j]);
                blue_interm[i][j] <= $signed(blue_cache[i][j]) * $signed(coeffs[i][j]);
            end
        end

        red_out <= (red_interm[0][0] + red_interm[0][1] + red_interm[0][2] + red_interm[1][0] + red_interm[1][1] + red_interm[1][2] + red_interm[2][0] + red_interm[2][1] + red_interm[2][2]) >>> shift;
        green_out <= (green_interm[0][0] + green_interm[0][1] + green_interm[0][2] + green_interm[1][0] + green_interm[1][1] + green_interm[1][2] + green_interm[2][0] + green_interm[2][1] + green_interm[2][2])  >>> shift;
        blue_out <= (blue_interm[0][0] + blue_interm[0][1] + blue_interm[0][2] + blue_interm[1][0] + blue_interm[1][1] + blue_interm[1][2] + blue_interm[2][0] + blue_interm[2][1] + blue_interm[2][2])  >>> shift;

        
     end


     kernels #(.K_SELECT(K_SELECT)) my_kernel(
  .rst(rst),
  .coeffs(coeffs),
  .shift(shift));

endmodule

`default_nettype wire

