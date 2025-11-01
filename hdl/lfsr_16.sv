`timescale 1ns / 1ps
`default_nettype none

module lfsr_16 (
        input wire clk,
        input wire rst,
        input wire [15:0] seed,
        output logic [15:0] q
    );

    logic [15:0] state;
    always_ff @( posedge clk ) begin
        
        if (rst) begin
            state <= seed;
        end else begin
            state <= { state[14] ^ state[15], state[13:2], state[1] ^ state[15], state[0], state[15] };
        end
    end

    assign q = state;

endmodule

`default_nettype wire
