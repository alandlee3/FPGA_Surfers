`timescale 1ns / 1ps
`default_nettype none
module sprite_creator (
        input wire clk,
        input wire rst,
        input wire signed [15:0] player_height,
        input wire [1:0] player_lane,
        input wire activate, // 1 cycle high activate
        input wire ducking, // if 1 then animate ducking for sprite

        output logic [47:0] vertex,
        output logic [15:0] color,
        output logic new_triangle,
        output logic active
    );

    localparam LEFTLANELEFT = -112;
    localparam LEFTLANERIGHT = -80;
    localparam MIDDLELANELEFT = -16;
    localparam MIDDLELANERIGHT = 16;
    localparam RIGHTLANELEFT = 80;
    localparam RIGHTLANERIGHT = 112;

    localparam DEPTH_CLOSE = 176;
    localparam DEPTH_FAR = 208;
    
    localparam GROUND = 128;
    localparam LANESTART = 64;
    localparam LANEEND = 512;

    localparam signed [15:0] Z_OFFSET = 0;

    logic [6:0] counter;
    logic [1:0] counter_mod_3;

    logic signed [15:0] vertex_x;
    logic signed [15:0] vertex_y;
    logic signed [15:0] vertex_z;

    logic signed [15:0] lane_left;
    logic signed [15:0] lane_right;

    assign vertex = { vertex_x, vertex_y, vertex_z+Z_OFFSET };

    typedef enum { 
        RST,
        IDLE,
        ACTIVE
    } sc_state;
    sc_state state;

    always_ff @( posedge clk ) begin
        new_triangle <= 0;
        active <= 0;

        if (rst) begin
            state <= RST;
        end else if(state == RST) begin
            state <= IDLE;
        end else if(state == IDLE) begin
            if(activate) begin
                lane_left <= (player_lane == 0) ? LEFTLANELEFT : (player_lane == 1) ? MIDDLELANELEFT : RIGHTLANELEFT;
                lane_right <= (player_lane == 0) ? LEFTLANERIGHT : (player_lane == 1) ? MIDDLELANERIGHT : RIGHTLANERIGHT;
                state <= ACTIVE;
                counter <= 0;
                counter_mod_3 <= 0;

                active <= 1;
            end
        end else if(state == ACTIVE) begin
            active <= 1;
            if(ducking) begin
                if(counter == 0) begin
                    vertex_x <= lane_left; // front 
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                    color <= 16'h0400;
                end else if(counter == 1) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 2) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 3) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 4) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 5) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 6) begin
                    color <= 16'h0200; // left side
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 7) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 8) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 9) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 10) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 11) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 12) begin // right side
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 13) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 14) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 15) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 16) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 17) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 18) begin
                    // top
                    color <= 16'h1404;
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 19) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 20) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 21) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 22) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 23) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 24) begin
                    // bottom
                    color <= 16'h2204;
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 25) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 26) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 27) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 28) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 29) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 16;
                    vertex_z <= DEPTH_CLOSE;
                end
            end else begin
                if(counter == 0) begin
                    vertex_x <= lane_left; // front 
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                    color <= 16'h0400;
                end else if(counter == 1) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 2) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 3) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 4) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 5) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 6) begin
                    color <= 16'h0200; // left side
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 7) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 8) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 9) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 10) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 11) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 12) begin // right side
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 13) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 14) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 15) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 16) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 17) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 18) begin
                    // top
                    color <= 16'h1404;
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 19) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 20) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 21) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 22) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 23) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 24) begin
                    // bottom
                    color <= 16'h2204;
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 25) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_CLOSE;
                end else if(counter == 26) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 27) begin
                    vertex_x <= lane_right;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 28) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_FAR;
                end else if(counter == 29) begin
                    vertex_x <= lane_left;
                    vertex_y <= -player_height - 32;
                    vertex_z <= DEPTH_CLOSE;
                end
            end

            // Lane Lines
            if (counter == 30) begin 
                vertex_x <= LEFTLANELEFT;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
                color <= 16'h0000; // black lane lines
            end else if (counter == 31) begin
                vertex_x <= LEFTLANELEFT+4;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 32) begin
                vertex_x <= LEFTLANELEFT;
                vertex_y <= GROUND;
                vertex_z <= LANEEND;
            end else if (counter == 33) begin
                vertex_x <= LEFTLANERIGHT;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 34) begin
                vertex_x <= LEFTLANERIGHT-4;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 35) begin
                vertex_x <= LEFTLANERIGHT;
                vertex_y <= GROUND;
                vertex_z <= LANEEND;
            end else if (counter == 36) begin 
                vertex_x <= MIDDLELANELEFT;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
                color <= 16'h0000; // black lane lines
            end else if (counter == 37) begin
                vertex_x <= MIDDLELANELEFT+4;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 38) begin
                vertex_x <= MIDDLELANELEFT;
                vertex_y <= GROUND;
                vertex_z <= LANEEND;
            end else if (counter == 39) begin
                vertex_x <= MIDDLELANERIGHT;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 40) begin
                vertex_x <= MIDDLELANERIGHT-4;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 41) begin
                vertex_x <= MIDDLELANERIGHT;
                vertex_y <= GROUND;
                vertex_z <= LANEEND;
            end else if (counter == 42) begin 
                vertex_x <= RIGHTLANELEFT;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 43) begin
                vertex_x <= RIGHTLANELEFT+4;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 44) begin
                vertex_x <= RIGHTLANELEFT;
                vertex_y <= GROUND;
                vertex_z <= LANEEND;
            end else if (counter == 45) begin
                vertex_x <= RIGHTLANERIGHT;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 46) begin
                vertex_x <= RIGHTLANERIGHT-4;
                vertex_y <= GROUND;
                vertex_z <= LANESTART;
            end else if (counter == 47) begin
                vertex_x <= RIGHTLANERIGHT;
                vertex_y <= GROUND;
                vertex_z <= LANEEND;
                state <= IDLE;
            end

            counter <= counter + 1;
            new_triangle <= (counter_mod_3 == 0);
            if(counter_mod_3 < 2) begin
                counter_mod_3 <= counter_mod_3 + 1;
            end else begin
                counter_mod_3 <= 0;
            end

        end
    end


endmodule

`default_nettype wire