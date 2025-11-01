`timescale 1ns / 1ps
`default_nettype none

module lfsr_4 (
        input wire clk,
        input wire rst,
        input wire [3:0] seed,
        output logic [3:0] q
    );

    logic [3:0] state;
    always_ff @( posedge clk ) begin
        
        if (rst) begin
            state <= seed;
        end else begin
            state <= { state[2:1], state[0] ^ state[3], state[3] };
        end
    end

    assign q = state;

endmodule

`default_nettype wire
