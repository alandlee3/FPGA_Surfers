`timescale 1ns / 1ps
`default_nettype none

module pipeline #(
        parameter WIDTH = 32,
        parameter STAGES_NEEDED = 1
    )
    (
        input wire clk,
        input wire [WIDTH-1:0] in,
        output logic [WIDTH-1:0] out
    );

    logic [WIDTH-1:0] pipeline [STAGES_NEEDED-1:0];

    always_ff @(posedge clk)begin
        pipeline[0] <= in;
        for (int i=1; i<STAGES_NEEDED; i = i+1)begin
            pipeline[i] <= pipeline[i-1];
        end
    end

    assign out = pipeline[STAGES_NEEDED-1];

endmodule

`default_nettype wire