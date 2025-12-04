`timescale 1ns / 1ps
`default_nettype none
// module to convert 16-bit obstacle data into a set of triangles, with vertices as output
module triangle_creator (
        input wire clk,
        input wire rst,
        input wire [15:0] obstacle, // 3 bits type, 2 bits lane, 11 bits depth (unsigned), the END of the obstacle
        input wire obstacle_valid,
        input wire done_in,
        output logic [47:0] vertex,
        output logic [15:0] color,
        output logic new_triangle,
        output logic done_out
    );

    // high level:
    // take in obstacle, look up what coordinates / offsets / triangles must be displayed
    // output vertices of each triangle one at a time
    // this means for each obstacle, may need up to 8 triangles --> 24 cycles, hopefully consecutively

    localparam signed [15:0] Z_OFFSET = 64;
    /*
    Types of obstacles:
    000 - No Obstacle
    001 - Barrier, Solid Low (must jump)
    010 - Barrier, Solid High (must duck)
    011 - Barrier, Middle (can either duck or jump)
    100 - Train Car
    101 - Ramp
    110 - Moving Car <- currently we do not generate moving cars.
    */
    localparam LEFTLANELEFT = -128;
    localparam LEFTLANERIGHT = -64;
    localparam MIDDLELANELEFT = -32;
    localparam MIDDLELANERIGHT = 32;
    localparam RIGHTLANELEFT = 64;
    localparam RIGHTLANERIGHT = 128;

    localparam GROUND = 128;
    localparam MID = 96;
    localparam TOP = 64;

    logic [2:0] obstacle_type;
    logic [1:0] obstacle_lane;
    logic signed [11:0] obstacle_depth;
    logic signed [15:0] lane_left;
    logic signed [15:0] lane_right;

    typedef enum { 
        RST,
        IDLE,
        GEN_TRIANGLE,
        OUTPUT
    } tc_state;
    tc_state state;

    logic [5:0] vertex_counter;
    logic [1:0] vertex_mod_3; // 0 = new triangle
    logic signed [15:0] vertex_x;
    logic signed [15:0] vertex_y;
    logic signed [15:0] vertex_z;

    localparam signed [15:0] MINZ = 8;

    assign vertex = { vertex_x, vertex_y, vertex_z < MINZ ? (MINZ+Z_OFFSET) : (vertex_z+Z_OFFSET) };

    always_ff @(posedge clk) begin
        done_out <= 0;
        new_triangle <= 0;

        if(rst) begin
            state <= RST;
        end else if(state == RST) begin
            state <= IDLE;
        end else if(state == IDLE) begin
            done_out <= done_in;

            if (obstacle_valid) begin
                obstacle_type <= obstacle[15:13];
                obstacle_lane <= obstacle[12:11];
                obstacle_depth <= {1'b0, obstacle[10:0]};
                lane_left <= (obstacle[12:11] == 0) ? LEFTLANELEFT : (obstacle[12:11] == 1) ? MIDDLELANELEFT : RIGHTLANELEFT;
                lane_right <= (obstacle[12:11] == 0) ? LEFTLANERIGHT : (obstacle[12:11] == 1) ? MIDDLELANERIGHT : RIGHTLANERIGHT;
                vertex_counter <= 0;
                vertex_mod_3 <= 0;

                state <= GEN_TRIANGLE;
            end
        end else if (state == GEN_TRIANGLE) begin
            if(obstacle_type == 1) begin
                // Solid low barrier

                if(obstacle_depth < 32 + MINZ) begin
                    // dont render, too close to camera z
                    state <= IDLE;
                end else if(vertex_counter == 0) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= GROUND;
                    color <= 16'hF000; // red barrier
                end else if (vertex_counter == 1) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                end else if(vertex_counter == 2) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= MID;
                end else if(vertex_counter == 3) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                end else if (vertex_counter == 4) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= MID;
                end else if(vertex_counter == 5) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= MID;

                    state <= IDLE;
                end
            end else if(obstacle_type == 2) begin
                // Solid high barrier

                if(obstacle_depth < 32 + MINZ) begin
                    // dont render, too close to camera z
                    state <= IDLE;
                end else if(vertex_counter == 0) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= MID;
                    color <= 16'hFE18; // pink barrier
                end else if (vertex_counter == 1) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= MID;
                end else if(vertex_counter == 2) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                end else if(vertex_counter == 3) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= MID;
                end else if (vertex_counter == 4) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= TOP;
                end else if(vertex_counter == 5) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                    state <= IDLE;
                end
            end else if(obstacle_type == 3) begin

                if(obstacle_depth < 32 + MINZ) begin
                    // dont render, too close to camera z
                    state <= IDLE;
                end else if(vertex_counter == 0) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= MID-8;
                    color <= 16'hFD00; // orange barrier
                end else if (vertex_counter == 1) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= MID-8;
                end else if(vertex_counter == 2) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= MID+8;
                end else if(vertex_counter == 3) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= MID-8;
                end else if (vertex_counter == 4) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_right;
                    vertex_y <= MID+8;
                end else if(vertex_counter == 5) begin
                    vertex_z <= obstacle_depth - 32;
                    vertex_x <= lane_left;
                    vertex_y <= MID+8;
                    state <= IDLE;
                end
            end else if(obstacle_type == 4) begin
                // train car !
                // needs 8 triangles... yikers

                if(vertex_counter == 0) begin
                    vertex_z <= obstacle_depth - 128;
                    vertex_x <= lane_left;
                    vertex_y <= GROUND;
                    color <= 16'h001F; // blue car
                end else if (vertex_counter == 1) begin
                    vertex_z <= obstacle_depth - 128;
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                end else if(vertex_counter == 2) begin
                    vertex_z <= obstacle_depth - 128;
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                end else if(vertex_counter == 3) begin
                    vertex_z <= obstacle_depth - 128;
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                end else if (vertex_counter == 4) begin
                    vertex_z <= obstacle_depth - 128;
                    vertex_x <= lane_right;
                    vertex_y <= TOP;
                end else if(vertex_counter == 5) begin
                    vertex_z <= obstacle_depth - 128;
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                end else if(vertex_counter == 6) begin
                    color <= 16'h000F; // sides of car
                    
                    // left side of car!

                    vertex_x <= lane_left;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 7) begin
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 8) begin
                    vertex_x <= lane_left;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 9) begin
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 10) begin
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 11) begin
                    vertex_x <= lane_left;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 12) begin
                    color <= 16'h000A; // sides of car
                    // Todo: reverse polarity of these sides
                    
                    // right side of car!
                    
                    vertex_x <= lane_right;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 13) begin
                    vertex_x <= lane_right;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 14) begin
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 15) begin
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 16) begin
                    vertex_x <= lane_right;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 17) begin
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 18) begin
                    color <= 16'h312F; // top of car
                    vertex_y <= TOP;
                    vertex_x <= lane_left;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 19) begin
                    vertex_y <= TOP;
                    vertex_x <= lane_right;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 20) begin
                    vertex_y <= TOP;
                    vertex_x <= lane_right;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 21) begin
                    vertex_y <= TOP;
                    vertex_x <= lane_right;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 22) begin
                    vertex_y <= TOP;
                    vertex_x <= lane_left;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 23) begin
                    vertex_y <= TOP;
                    vertex_x <= lane_left;
                    vertex_z <= obstacle_depth - 128;

                    state <= IDLE;
                end
            end else if(obstacle_type == 5) begin
                // train ramp


                if(vertex_counter == 0) begin
                    color <= 16'hfee4; //sides of ramp

                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 1) begin
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 2) begin
                    vertex_x <= lane_left;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 3) begin
                    vertex_x <= lane_left;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 4) begin
                    vertex_x <= lane_left;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 5) begin
                    vertex_x <= lane_left;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 6) begin
                    vertex_x <= lane_right;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 7) begin
                    vertex_x <= lane_right;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 8) begin
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 9) begin
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 10) begin
                    vertex_x <= lane_right;
                    vertex_y <= TOP;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 11) begin
                    vertex_x <= lane_right;
                    vertex_y <= GROUND;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 12) begin
                    // top of ramp
                    color <= 16'h8200;
                    vertex_y <= GROUND;
                    vertex_x <= lane_left;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 13) begin
                    vertex_y <= GROUND;
                    vertex_x <= lane_right;
                    vertex_z <= obstacle_depth - 128;
                end else if(vertex_counter == 14) begin
                    vertex_y <= TOP;
                    vertex_x <= lane_right;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 15) begin
                    vertex_y <= TOP;
                    vertex_x <= lane_right;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 16) begin
                    vertex_y <= TOP;
                    vertex_x <= lane_left;
                    vertex_z <= obstacle_depth;
                end else if(vertex_counter == 17) begin
                    vertex_y <= GROUND;
                    vertex_x <= lane_left;
                    vertex_z <= obstacle_depth - 128;

                    state <= IDLE;
                end
            end

            new_triangle <= (vertex_mod_3 == 0);
            vertex_counter <= vertex_counter + 1;
            if (vertex_mod_3 < 2) begin
                vertex_mod_3 <= vertex_mod_3 + 1;
            end else begin
                vertex_mod_3 <= 0;
            end
        end
    end


    
endmodule

`default_nettype wire