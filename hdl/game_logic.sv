`timescale 1ns / 1ps
`default_nettype none
module game_logic #(
        parameter HALF_BLOCK_LENGTH = 64, // length in "score points" of half block
        parameter GRAVITY = 3, // how much vertical velocity decreases per frame
        parameter DUCK_LIMIT = 15, // how long a duck lasts for
        parameter VERTICAL_JUMP = 10, // how much vertical velocity a jump gives 
    )(
        input wire clk,
        input wire rst,
        input wire new_frame,
        input wire [15:0] obstacle,
        input wire duck,
        input wire jump,
        input wire left,
        input wire right,
        input wire firstrow, // high only if obstacle is in the first row (valid to check collisions)
        output logic game_over,
        output logic [1:0] player_lane,
        output logic signed [15:0] player_height,
        output logic [15:0] player_score
    );

    // high level:
    // big boi fsm
    // ducking supersedes jumping in priority if applied together
    // can interrupt jump with duck, but not duck with jump 

    // lots of state variables
    // [15:0] player_height already above
    // [15:0] player_score already above
    // [1:0] player_lane above
    // game_over above
    logic airborne;
    logic ducking;
    logic [$clog2(DUCK_LIMIT)-1:0] ducking_duration;
    logic signed [7:0] vertical_velocity;
    logic [$clog2(HALF_BLOCK_LENGTH)-1:0] half_block_progress;

    logic [15:0] ground_level; // for where we fall to after jumping, determined by obstacle

    always_ff @(posedge clk) begin
        if (rst) begin
            player_height <= 0;
            player_score <= 0;
            player_lane <= 1;
            game_over <= 0;
            airborne <= 0;
            ducking <= 0;
            ducking_duration <= 0;
            vertical_velocity <= 0;
            half_block_progress <= 0;
        end else begin
            // TODO: looking out for the correct obstacle
            // for ground level, and to determine collisions (and gravity if ramp)
            // we *could* modify game_over if incoming obstacle immediately makes collision
            // Types of obstacles:
            // 000 - No Obstacle
            // 001 - Barrier, Solid Low (must jump)
            // 010 - Barrier, Solid High (must duck)
            // 011 - Barrier, Middle (can either duck or jump)
            // 100 - Train Car
            // 101 - Ramp
            // 110 - Moving Car <- currently we do not generate moving cars.

            if (new_frame) begin
                // lane changes
                if (left && player_lane >= 1) begin
                    player_lane <= player_lane - 1;
                end else if (right && player_lane <= 1) begin
                    player_lane <= player_lane + 1;
                end

                // ducking/ducking duration
                if (ducking) begin
                    if (ducking_duration <= DUCK_LIMIT - 1) begin
                        // player has no control over ducking for a while after ducking
                        ducking_duration <= ducking_duration + 1;
                    end else begin
                        if (duck) begin
                            // immediately restart ducking 
                            ducking <= 1;
                            ducking_duration <= 1;
                        end else begin 
                            // no more ducking
                            ducking_duration <= 0;
                            ducking <= 0;
                        end
                    end
                end else if (duck && !ducking) begin
                    // initiate ducking
                    ducking <= 1;
                    ducking_duration <= 1;
                    // TODO: ducking logic if we are airborne (see below)
                end

                // jumping/airborne-ness
                // TODO
            end
        end
    end

    // sample pipeline stuff
    // pipeline #(.WIDTH(1), .STAGES_NEEDED(16) ) xdiv_p
    // (
    //     .clk(clk),
    //     .in(xcoordneg),
    //     .out(xcoordneg_div)
    // );

    // always_comb begin

    // end


    
endmodule

`default_nettype wire