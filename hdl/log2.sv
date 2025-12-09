`timescale 1ns / 1ps
`default_nettype none

// technically computes log2 + 1 but cope cope cope
// used for reducing divisions to a reasonable size.
module log2 (
    input wire clk,
    input  wire signed [19:0] c,
    output logic [4:0] e
);

    logic [19:0] abs_c;
    integer i;

    assign abs_c = (c < 0) ? -c : c;

    always_comb begin
        e = 0;

        for (i = 19; i >= 0; i = i - 1) begin
            if (abs_c[i]) begin
                e = i + 1;
                break;
            end
        end

        if (abs_c == 0)
            e = 0;
    end

endmodule

`default_nettype wire