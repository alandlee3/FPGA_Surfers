`timescale 1ns / 1ps
`default_nettype none

module full_projector (
    input wire clk,
    input wire rst,
    input wire [15:0] obstacle,
    input wire obstacle_valid,
    input wire done_in,

    output logic [127:0] triangle,
    output logic triangle_valid,
    output logic done_out
    );

    logic [47:0] vertex;
    logic [15:0] color;
    logic new_triangle;
    logic int_done;

    triangle_creator tcreator_inst (
        .clk(clk),
        .rst(rst),
        .obstacle(obstacle),
        .obstacle_valid(obstacle_valid),
        .done_in(done_in),
        .vertex(vertex),
        .color(color),
        .new_triangle(new_triangle),
        .done_out(int_done)
    );

    ddd_projector ddd_inst (
        .clk(clk),
        .rst(rst),
        .vertex(vertex),
        .color(color),
        .new_triangle_in(new_triangle),
        .done_in(int_done),
        .triangle(triangle),
        .new_triangle_out(triangle_valid),
        .done_out(done_out)
    );

endmodule

`default_nettype wire