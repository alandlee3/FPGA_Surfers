`timescale 1ns / 1ps
`default_nettype none

// 16 stage pipeline

module divider3 #(parameter WIDTH = 16) (
        input wire clk,
        input wire rst,
        input wire[WIDTH-1:0] dividend_in,
        input wire[WIDTH-1:0] divisor_in,
        input wire data_valid_in,
        output logic[WIDTH-1:0] quotient_out,
        output logic[WIDTH-1:0] remainder_out,
        output logic data_valid_out,
        output logic error_out,
        output logic busy_out
    );

    logic [15:0] p[15:0]; //16 stages
    logic [15:0] dividend [15:0];
    logic [15:0] divisor [15:0];
    logic data_valid [15:0];

    assign data_valid_out = data_valid[15];
    assign quotient_out = dividend[15];
    assign remainder_out = p[15];

    always_ff @(posedge clk)begin
        data_valid[0] <= data_valid_in;
        if (data_valid_in)begin
            divisor[0] <= divisor_in;
            if ({15'b0,dividend_in[15]}>=divisor_in[15:0])begin
                p[0] <= {15'b0,dividend_in[15]} - divisor_in[15:0];
                dividend[0] <= {dividend_in[14:0],1'b1};
            end else begin
                p[0] <= {15'b0,dividend_in[15]};
                dividend[0] <= {dividend_in[14:0],1'b0};
            end
        end
        for (int i=1; i<16; i=i+1)begin
            data_valid[i] <= data_valid[i-1];
            if ({p[i-1][14:0],dividend[i-1][15]}>=divisor[i-1][15:0])begin
                p[i] <= {p[i-1][14:0],dividend[i-1][15]} - divisor[i-1][15:0];
                dividend[i] <= {dividend[i-1][14:0],1'b1};
            end else begin
                p[i] <= {p[i-1][14:0],dividend[i-1][15]};
                dividend[i] <= {dividend[i-1][14:0],1'b0};
            end
            divisor[i] <= divisor[i-1];
        end
    end
endmodule

`default_nettype wire
