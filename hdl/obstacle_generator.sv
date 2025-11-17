`timescale 1ns / 1ps
`default_nettype none

module obstacle_generator #(
    parameter CYCLES_PER_OBSTACLE = 30
) (
    input wire clk,
    input wire rst,
    input wire activate, // one cycle high activate

    output logic valid,
    output logic first_row,
    output logic [15:0] obstacle, // 3 bits type, 2 bits lane, 11 bits depth (unsigned), the END of the obstacle
    output logic done
);

    // 16 x 3 array of 4 bit obstacles
    // [2:0] is the type of obstacle
    // [3] is if it's the first (closer) half. 1 is true.
    logic [3:0] obstacle_storage [15:0][2:0];

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

    /*
    Each train car is 128 units in depth and 64 units in height.
    Each half block is thus 64 units in depth.
    */

    /////////// Pseudo-RNG

    logic [17:0] rng;

    always_ff @( posedge clk ) begin
        rng <= rng + 18'h3a039; // some random shit
    end

    /////////// FSM

    localparam SPEED = 4;
    localparam HALF_BLOCK = 64;
    localparam LOG_HALF_BLOCK = $clog2(HALF_BLOCK);
    localparam LOG_CYCLES = $clog2(CYCLES_PER_OBSTACLE);

    typedef enum { 
        RST,
        IDLE,
        OBSTACLE_SHIFT,
        GENERATION,
        OUTPUT,
        DONE
    } og_state;
    og_state state;

    logic [LOG_HALF_BLOCK-1:0] current_depth;

    logic [LOG_CYCLES-1:0] output_cycle;
    logic [1:0] output_lane;
    logic [3:0] output_block;

    // depth of the end of an obstacle while iterating
    logic [10:0] depth;

    logic next_cycle_valid;

    assign next_cycle_valid = ( obstacle_storage[0][output_lane][3] == 0) && obstacle_storage[0][output_lane][2:0] != 0;

    always_ff @( posedge clk ) begin
        valid <= 0;
        done <= 0;
        
        if (rst) begin
            state <= RST;
        end else if (state == RST) begin
            for (int j = 0; j < 3; j=j+1) begin
                for (int i = 0; i < 16; i=i+1) begin
                    obstacle_storage[i][j] <= 0;
                end
            end

            state <= IDLE;
            current_depth <= 0;
        end else if (state == IDLE) begin
            if (activate) begin
                state <= OBSTACLE_SHIFT;
            end
        end else if (state == OBSTACLE_SHIFT) begin
            current_depth <= current_depth + SPEED;

            if (current_depth >= HALF_BLOCK - SPEED) begin

                // must shift all obstacles forward
                for(int j = 0; j < 3; j=j+1) begin
                    for (int i = 0; i < 15; i=i+1) begin
                        obstacle_storage[i][j] <= obstacle_storage[i+1][j];
                    end

                    obstacle_storage[15][j] <= 0;
                end

                state <= GENERATION;

            end else begin
                state <= OUTPUT;
                output_cycle <= 0;
                output_lane <= 0;
                output_block <= 0;
                depth <= HALF_BLOCK - SPEED - current_depth;
            end
        end else if(state == GENERATION) begin
            
            // We don't generate adjacent obstacles. Wait until row in front is clear as well.

            // 7/8 probability empty
            // Otherwise: 1/2 ( 1/2 -> barrier, 1/4 -> duck barrier, 1/4 -> jump barrier )
            //           1/2 ( 3/4 Train car, 1/4 Ramp )


            for (int j = 0; j < 3; j=j+1) begin
                // if ( rng[5*j+1] == 0 && rng[5*j] == 0 && obstacle_storage[14][j] == 0 ) begin
                    // 1/4 probability, using 5j+1:5j

                if(1) begin

                    if (rng[5*j+2] == 0) begin
                        // 1/2 probability, generating a barrier

                        if (rng[5*j+4] == 0 && rng[5*j+3] == 0) begin
                            // 1/4 probability jump barrier
                            obstacle_storage[15][j] <= 4'b1;
                        end else if (rng[5*j+4] == 0 && rng[5*j+3] == 1) begin
                            // 1/4 probability duck barrier
                            obstacle_storage[15][j] <= 4'b10;
                        end else begin
                            // 1/2 probability barrier
                            obstacle_storage[15][j] <= 4'b11;
                        end
                    end else begin
                        if (rng[5*j+4] == 0 && rng[5*j+3] == 0) begin
                            // 1/4 probability ramp
                            obstacle_storage[15][j] <= 4'b0101;
                            obstacle_storage[14][j] <= 4'b1101;
                        end else begin
                            obstacle_storage[15][j] <= 4'b0100;
                            obstacle_storage[14][j] <= 4'b1100;
                        end
                    end
                end
            end

            state <= OUTPUT;
            output_cycle <= 0;
            output_lane <= 0;
            output_block <= 0;
            depth <= HALF_BLOCK - current_depth;

        end else if (state == OUTPUT) begin
            
            if (output_cycle < CYCLES_PER_OBSTACLE-1) begin
                output_cycle <= output_cycle + 1;
            end else begin

                if (next_cycle_valid) begin
                    output_cycle <= 0;
                end

                // output here!

                // Output only if we're dealing with the latter half of the obstacle!
                valid <= next_cycle_valid;
                obstacle <= { obstacle_storage[0][output_lane][2:0], output_lane, depth };
                first_row <= output_block == 0 || (output_block == 1 && obstacle_storage[0][output_lane][2]);

                if (output_lane < 2) begin
                    output_lane <= output_lane + 1;
                end else begin
                    output_lane <= 0;
                    depth <= depth + HALF_BLOCK;

                    // shift obstacles forward
                    for(int j = 0; j < 3; j=j+1) begin
                        for (int i = 0; i < 15; i=i+1) begin
                            obstacle_storage[i][j] <= obstacle_storage[i+1][j];
                        end

                        obstacle_storage[15][j] <= obstacle_storage[0][j];
                    end

                    if (output_block < 15) begin
                        output_block <= output_block + 1;
                    end else begin
                        output_block <= 0;

                        // we're done!
                        state <= DONE;
                    end
                end
            end

        end else if (state == DONE) begin
            done <= 1;

            if(activate) begin
                state <= OBSTACLE_SHIFT;
            end
        end
    end

endmodule

`default_nettype wire
