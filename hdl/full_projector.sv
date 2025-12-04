`timescale 1ns / 1ps
`default_nettype none

module full_projector (
    input wire clk,
    input wire rst,
    input wire [15:0] obstacle,
    input wire obstacle_valid,
    input wire done_in,
    
    input wire signed [15:0] player_height,
    input wire [1:0] player_lane,
    input wire ducking,

    output logic [127:0] triangle,
    output logic triangle_valid,
    output logic done_out
    );

    logic activate_screator;
    logic screator_active;

    logic [47:0] s_vertex;
    logic [15:0] s_color;
    logic s_new_triangle;

    typedef enum { 
        RST,
        OBSTACLES,
        WAIT,
        SPRITE,
        PROJECTING,
        DONE
    } fp_state;
    fp_state state;

    sprite_creator screator_inst (
        .clk(clk),
        .rst(rst),
        .player_height(player_height),
        .player_lane(player_lane),
        .activate(activate_screator),
        .ducking(ducking),

        .vertex(s_vertex),
        .color(s_color),
        .new_triangle(s_new_triangle),
        .active(screator_active)
    );

    logic [47:0] o_vertex;
    logic [15:0] o_color;
    logic o_new_triangle;

    logic o_done;

    triangle_creator tcreator_inst (
        .clk(clk),
        .rst(rst),
        .obstacle(obstacle),
        .obstacle_valid(obstacle_valid),
        .done_in(done_in),
        .vertex(o_vertex),
        .color(o_color),
        .new_triangle(o_new_triangle),
        .done_out(o_done)
    );

    logic s_done;

    logic [47:0] vertex;
    logic [15:0] color;
    logic new_triangle;

    assign vertex = (state == SPRITE) ? s_vertex : o_vertex;
    assign color = (state == SPRITE) ? s_color : o_color;
    assign new_triangle = (state == SPRITE) ? s_new_triangle : o_new_triangle;

    logic ddd_done;

    ddd_projector ddd_inst (
        .clk(clk),
        .rst(rst),
        .vertex(vertex),
        .color(color),
        .new_triangle_in(new_triangle),
        .done_in(s_done),
        .triangle(triangle),
        .new_triangle_out(triangle_valid),
        .done_out(ddd_done)
    );

    always_ff @( posedge clk ) begin
        s_done <= 0;
        done_out <= 0;
        activate_screator <= 0;

        if(rst) begin
            state <= RST;
        end else if(state == RST) begin
            state <= OBSTACLES;
        end else if(state == OBSTACLES) begin
            if(o_done) begin
                state <= WAIT;
                activate_screator <= 1;
            end
        end else if(state == WAIT) begin
            state <= SPRITE;
        end else if(state == SPRITE) begin
            if(!screator_active) begin
                state <= PROJECTING;
            end
        end else if(state == PROJECTING) begin
            s_done <= 1;
            if(ddd_done) begin
                state <= DONE;
            end
        end else if(state == DONE) begin
            done_out <= 1;

            if(done_in == 0) begin
                done_out <= 0;
                state <= OBSTACLES;
            end
        end
    end

endmodule

`default_nettype wire