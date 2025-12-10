`timescale 1ns / 1ps
`default_nettype none

module speed_params (
    input wire [3:0] speed,
    output logic [5:0] gravity,
    output logic [7:0] duck_limit,
    output logic [9:0] vertical_jump
);

always_comb begin
    if (speed == 1) begin
        gravity = 1;
        duck_limit = 128;
        vertical_jump = 108;
    end else if (speed == 2) begin
        gravity = 4;
        duck_limit = 64;
        vertical_jump = 220;
    end else if (speed == 4) begin
        gravity = 15;
        duck_limit = 32;
        vertical_jump = 420;
    end else if (speed == 8) begin
        gravity = 60;
        duck_limit = 16;
        vertical_jump = 820; 
    end else begin
        gravity = 1;
        duck_limit = 128;
        vertical_jump = 108;
    end
end



endmodule

`default_nettype wire
