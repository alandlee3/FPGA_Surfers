`timescale 1ns / 1ps
`default_nettype none

// pipeline 9 stages 

module small_multiplier (
    input  wire         clk,
    input  wire signed [10:0] signed_11,
    input  wire signed [7:0]  signed_8,
    output logic signed [18:0] signed_output
);

    // stored multiplicands
    logic signed [10:0] a_r [7:0];
    logic signed [7:0]  b_r [7:0];

    // sign ext a_r
    logic signed [18:0] a19_r [7:0];

    always_ff @(posedge clk) begin
        // Stage 0 inputs
        a_r[0] <= signed_11;
        b_r[0] <= signed_8;

        // Shift pipeline
        for (int i = 1; i < 8; i=i+1) begin
            a_r[i] <= a_r[i-1];
            b_r[i] <= b_r[i-1];
        end
    end

    always_comb begin
        for (int sm_i = 0; sm_i < 8; sm_i=sm_i+1) begin
            // sign-extend 11-bit signed to 19 bits
            a19_r[sm_i] = { {8{a_r[sm_i][10]}}, a_r[sm_i] };
        end
    end

    logic signed [18:0] sum [7:0];

    always_ff @(posedge clk) begin
        if (b_r[0][0])
            sum[0] <= a19_r[0];
        else
            sum[0] <= 19'sd0;
    end

    genvar i;
    generate
        for (i = 1; i < 7; i=i+1) begin : stages
            always_ff @(posedge clk) begin
                if (b_r[i][i])
                    sum[i] <= sum[i-1] + (a19_r[i] <<< i);
                else
                    sum[i] <= sum[i-1];
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (b_r[7][7])
            sum[7] <= sum[6] - (a19_r[7] <<< 7);
        else
            sum[7] <= sum[6];
    end

    assign signed_output = sum[7];

endmodule

`default_nettype wire
