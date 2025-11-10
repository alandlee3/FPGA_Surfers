`timescale 1ns / 1ps
`default_nettype none
// module to convert 16-bit obstacle data into a set of triangles, with vertices as output
module triangle_creator (
        input wire clk,
        input wire rst,
        input wire [15:0] obstacle,
        input wire obstacle_valid,
        input wire done_in,
        output logic ready, // not high if we are still taking the obstacle and converting it to triangles
        output logic [47:0] vertex,
        output logic [15:0] color,
        output logic new_triangle,
        output logic done_out
    );

    // high level:
    // take in obstacle, look up what coordinates / offsets / triangles must be displayed
    // output vertices of each triangle one at a time
    // this means for each obstacle, may need up to 8 triangles --> 24 cycles, hopefully consecutively

    // sample pipeline stuff
    // pipeline #(.WIDTH(1), .STAGES_NEEDED(16) ) xdiv_p
    // (
    //     .clk(clk),
    //     .in(xcoordneg),
    //     .out(xcoordneg_div)
    // );

    // always_comb begin

    // end

    // always_ff @(posedge clk) begin

    // end


    
endmodule

`default_nettype wire