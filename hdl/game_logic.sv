`timescale 1ns / 1ps
`default_nettype none
module game_logic #(
        parameter HALF_BLOCK_LENGTH = 64, // length in "score points" of half block
        parameter GRAVITY = 1, // how much vertical velocity decreases (in 128ths) per frame
        parameter DUCK_LIMIT = 15, // how long a duck lasts for
        parameter VERTICAL_JUMP = 190, // how much vertical velocity a jump gives (in 128ths)
        parameter SPEED = 1, // how many "score points" we move up per frame, MUST divide HALF_BLOCK_LENGTH/2
        parameter GROUND = -128, // where the floor of the game is (no train car)
        parameter MARGIN_OF_ERROR = 10 // how below the ground level of a train car we can be without dying
    )(
        input wire clk,
        input wire rst,
        input wire new_frame,
        input wire [15:0] obstacle,
        input wire obstacle_valid,
        input wire duck,
        input wire jump,
        input wire left,
        input wire right,
        input wire firstrow, // high only if obstacle is in the first row (valid to check collisions)
        output logic game_over,
        output logic [1:0] player_lane,
        output logic signed [15:0] player_height,
        output logic [15:0] player_score,
        output logic obstacle_in_half_block,
        output logic signed [15:0] ground_level,
        output logic [5:0] half_block_progress,
        output logic ducking
    );

    // high level:
    // ducking supersedes jumping in priority if applied together
    // can interrupt jump with duck and duck with jump

    // lots of state variables
    // [15:0] player_height already above
    // [15:0] player_score already above
    // [1:0] player_lane above
    // game_over above
    logic airborne;
    logic [$clog2(DUCK_LIMIT)-1:0] ducking_duration;
    logic signed [13:0] vertical_velocity_128ths;
    logic signed [13:0] new_vertical_velocity_128ths;
    // logic [$clog2(HALF_BLOCK_LENGTH)-1:0] half_block_progress;

    // logic signed [15:0] ground_level; // for where we fall to after jumping, determined by obstacle

    assign airborne = (player_height > ground_level);

    always_comb begin
        if (airborne || vertical_velocity_128ths - GRAVITY > 0) begin
            new_vertical_velocity_128ths = vertical_velocity_128ths - GRAVITY;
        end else begin
            new_vertical_velocity_128ths = 0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            player_height <= 0;
            player_score <= 0;
            player_lane <= 1;
            game_over <= 0;
            ducking <= 0;
            ducking_duration <= 0;
            vertical_velocity_128ths <= 0;
            half_block_progress <= 0;
        end else begin
            // OBSTACLE PROCESSING
            if (obstacle_valid && firstrow && (obstacle[12:11] == player_lane) && !game_over) begin
                obstacle_in_half_block <= 1;
                case(obstacle[15:13])
                    3'b001: begin // Barrier, Solid Low (must jump)
                        ground_level <= $signed(GROUND);
                        if (half_block_progress == HALF_BLOCK_LENGTH/2) begin
                            // check for non-jumping behavior
                            if (player_height <= $signed(GROUND+HALF_BLOCK_LENGTH/2)) begin
                                game_over <= 1;
                            end
                        end
                    end
                    3'b010: begin // Barrier, Solid High (must duck unless very high)
                        ground_level <= $signed(GROUND);
                        if (half_block_progress == HALF_BLOCK_LENGTH/2) begin
                            // check for non-ducking behavior
                            game_over <= (!ducking && (player_height <= $signed(GROUND + HALF_BLOCK_LENGTH)));
                        end
                    end
                    3'b011: begin // Barrier, Middle (can either duck or jump)
                        ground_level <= $signed(GROUND);
                        if (half_block_progress == HALF_BLOCK_LENGTH/2) begin
                            // check for non-jumping and non-ducking behavior
                            if (player_height <= $signed(GROUND+HALF_BLOCK_LENGTH/2) && !ducking) begin
                                game_over <= 1;
                            end
                        end
                    end
                    3'b100: begin // Train Car
                        ground_level <= $signed(GROUND+HALF_BLOCK_LENGTH);
                        // check for colliding with train car
                        if (player_height <= $signed(GROUND+HALF_BLOCK_LENGTH) - MARGIN_OF_ERROR) begin
                            game_over <= 1;
                        end
                    end
                    3'b101: begin
                        // TODO if time, figure out why 0xFF9F --> 0xFF95 height halfway thru car

                        // firstrow is only high if we are intersecting halfblock.
                        // 64-128 implies we are in the 2nd halfblock of a ramp
                        if (obstacle[10:0] <= 255) begin
                            ground_level <= $signed(GROUND + HALF_BLOCK_LENGTH/2 + (half_block_progress >> 1));
                            if (player_height <= GROUND - MARGIN_OF_ERROR + $signed(HALF_BLOCK_LENGTH/2 + (half_block_progress >> 1))) begin
                                game_over <= 1;
                            end
                        end
                        // 64-127 implies we are in the 1st halfblock of a ramp
                        else if (obstacle[10:0] <= 319 && obstacle[10:0] >= 256) begin
                            ground_level <= $signed(GROUND + (half_block_progress >> 1));
                            if (player_height <= GROUND - MARGIN_OF_ERROR + $signed(half_block_progress >> 1)) begin
                                game_over <= 1;
                            end
                        end
                    end
                    3'b110: ; // Moving Car <- currently we do not generate moving cars. TODO later
                    default: ;
                endcase
            end

            // GAME PROGRESSION
            if (new_frame && !game_over) begin
                // player moves forward
                player_score <= player_score + SPEED;
                if (half_block_progress < HALF_BLOCK_LENGTH - SPEED) begin
                    half_block_progress <= half_block_progress + SPEED;
                end else begin
                    half_block_progress <= 0;
                end

                // lane changes
                // TODO: kill player if they try to go off the 3 lanes
                if (left && player_lane >= 1) begin
                    player_lane <= player_lane - 1;
                end else if (right && player_lane <= 1) begin
                    player_lane <= player_lane + 1;
                end

                // DUCKING
                if (ducking) begin
                    // 3. jumping out of ducking
                    if (jump) begin
                        ducking <= 0;
                        player_height <= player_height + (VERTICAL_JUMP / 64);
                        vertical_velocity_128ths <= VERTICAL_JUMP;
                    end

                    else if (ducking_duration < DUCK_LIMIT - 1) begin
                        // player has no control over ducking for a while after ducking
                        ducking_duration <= ducking_duration + 1;
                        player_height <= ground_level;
                    end else begin
                        player_height <= ground_level;
                        if (duck) begin
                            // 2. more ducking
                            ducking <= 1;
                            ducking_duration <= 1;
                        end else begin 
                            // 1. doing nothing
                            ducking_duration <= 0;
                            ducking <= 0;
                        end
                    end
                end

                // AIRBORNE
                else if (airborne) begin
                    // 2. ducking
                    if (duck) begin
                        vertical_velocity_128ths <= $signed(-VERTICAL_JUMP);
                        if (ground_level < player_height + $signed(-VERTICAL_JUMP/128)) begin
                            player_height <= player_height + $signed(-VERTICAL_JUMP/128);
                        end else begin
                            player_height <= ground_level;
                        end
                    end

                    // 1. doing nothing
                    // 3. trying to jump again --> transition to running state and then re-jump
                    else if ($signed(player_height) + $signed(new_vertical_velocity_128ths >>> 7) < $signed(ground_level)) begin // hitting ground level
                        if ($signed(player_height) + $signed(new_vertical_velocity_128ths >>> 7) >= $signed(ground_level) - MARGIN_OF_ERROR) begin
                            player_height <= ground_level;
                            vertical_velocity_128ths <= 0;
                        end else begin
                            game_over <= 1;
                        end
                    end else begin // still gonna be in the air
                        vertical_velocity_128ths <= new_vertical_velocity_128ths;
                        player_height <= $signed(player_height) + $signed(new_vertical_velocity_128ths >>> 7);
                    end
                end

                // PLAIN RUNNING
                else begin
                    // 2. ducking
                    if (duck) begin
                        player_height <= ground_level;
                        // initiate ducking
                        ducking <= 1;
                        ducking_duration <= 1;
                    end

                    // 3. jumping
                    else if (jump) begin
                        player_height <= player_height + $signed(VERTICAL_JUMP/128);
                        vertical_velocity_128ths <= VERTICAL_JUMP;
                    end

                    // 1. doing nothing
                    else begin
                        player_height <= ground_level;
                    end
                end

                if (!obstacle_in_half_block) ground_level <= $signed(GROUND); // set as default for next frame, unless an obstacle is detected
                obstacle_in_half_block <= 0;
            end
        end
    end
    
endmodule

`default_nettype wire