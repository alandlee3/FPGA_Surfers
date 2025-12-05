`timescale 1ns / 1ps
`default_nettype none
// 18 cycle projection module.
// 16 cycles are due to division, 2 more for getting all 3 vertices out
// we get a vertex inputs which are still (0,0) at center of screen, so need to offset
// all coordinates by (WIDTH/2, HEIGHT/2).
module ddd_projector #(
        parameter LOG_D = 8,
        parameter WIDTH = 1280,
        parameter HEIGHT = 720
    )(
        input wire clk,
        input wire rst,
        input wire [47:0] vertex,
        input wire [15:0] color,
        input wire new_triangle_in, // high once at beginning of triangle
        input wire done_in, // done feeding all triangles
        output logic [127:0] triangle, // color|p1x|p1y|p2x|p2y|p3x|p3y|'depth'
        output logic new_triangle_out,
        output logic done_out
    );

    logic [15:0] color_out; // stores color to output after waiting 18 cycles for division/vertex collection
    logic [15:0] xcoord, ycoord, zcoord; // extracting unsigned coordinate data from vertex
    logic [15:0] xcoordz0, ycoordz0; // multiplying by plane we project onto
    logic xcoordneg, ycoordneg, zcoordneg; // extracting signedness data from vertex
    logic xcoordneg_div, ycoordneg_div, zcoordneg_div; // pipelined signedness data after division

    assign xcoordneg = vertex[47];
    assign ycoordneg = vertex[31];
    assign zcoordneg = vertex[15];
    assign xcoord = xcoordneg ? 16'hFFFF - vertex[47:32] + 1: vertex[47:32];
    assign ycoord = ycoordneg ? 16'hFFFF - vertex[31:16] + 1: vertex[31:16];
    assign zcoord = zcoordneg ? 16'hFFFF - vertex[15:0] + 1: vertex[15:0];
    assign xcoordz0 = xcoord << LOG_D;
    assign ycoordz0 = ycoord << LOG_D;


    pipeline #(.WIDTH(1), .STAGES_NEEDED(16) ) xdiv_p
    (
        .clk(clk),
        .in(xcoordneg),
        .out(xcoordneg_div)
    );

    pipeline #(.WIDTH(1), .STAGES_NEEDED(16) ) ydiv_p
    (
        .clk(clk),
        .in(ycoordneg),
        .out(ycoordneg_div)
    );

    pipeline #(.WIDTH(1), .STAGES_NEEDED(18) ) done_p
    (
        .clk(clk),
        .in(done_in),
        .out(done_out)
    );

    pipeline #(.WIDTH(16), .STAGES_NEEDED(18) ) color_p
    (
        .clk(clk),
        .in(color),
        .out(color_out)
    );

    logic [17:0] new_triangle_buffer; // keeps track of where triangles are along pipeline
    logic [15:0][15:0] depth_buffer; // keeps track of the matching depths along pipeline, but minus 2 cycles since those were used to compute depth
    logic [15:0] final_depth; // computes sum of 3 closest-to-end depths in case this gives us a triangle we want
    
    // see if we are actually dividing something, because a new triangle was inputted in last 3 clock cycles
    logic division_input_valid;
    assign division_input_valid = (new_triangle_in || new_triangle_buffer[0] || new_triangle_buffer[1]);

    // registers to store immediate (unsigned) result of divisions
    logic [15:0] x_division_unsigned, y_division_unsigned;

    // registers to store the last 3 division results in case it's a triangle
    // these should be correctly offset now
    logic [2:0][15:0] x_division_results, y_division_results;

    divider3 #(.WIDTH(16)) xcoord_divider (
        .clk(clk),
        .rst(rst),
        .dividend_in(xcoordz0),
        .divisor_in(zcoord),
        .data_valid_in(division_input_valid),
        .quotient_out(x_division_unsigned),
        .remainder_out(),
        .data_valid_out(),
        .error_out(),
        .busy_out()
    );

    divider3 #(.WIDTH(16)) ycoord_divider (
        .clk(clk),
        .rst(rst),
        .dividend_in(ycoordz0),
        .divisor_in(zcoord),
        .data_valid_in(division_input_valid),
        .quotient_out(y_division_unsigned),
        .remainder_out(),
        .data_valid_out(),
        .error_out(),
        .busy_out()
    );

    // convert divisions back to signed results and start accumulating to buffer
    assign x_division_results[0] = (xcoordneg_div ? 16'hFFFF - x_division_unsigned + 1: x_division_unsigned) + WIDTH/2;
    assign y_division_results[0] = (ycoordneg_div ? 16'hFFFF - y_division_unsigned + 1: y_division_unsigned) + HEIGHT/2;

    // new triangle ready for output
    always_comb begin
        new_triangle_out = new_triangle_buffer[17];
        if (new_triangle_buffer[17]) begin
            // need to grab all the results
            triangle = {color_out, x_division_results[2], y_division_results[2], x_division_results[1], y_division_results[1], x_division_results[0], y_division_results[0], final_depth};
        end else begin
            triangle = 0;
        end
    end

    always_ff @(posedge clk) begin
        // calculate depth over two cycles, then pipeline while waiting for division
        logic [15:0] xcoord_sq, ycoord_sq, zcoord_sq;
        xcoord_sq <= (xcoord >> 4) * (xcoord >> 4);
        ycoord_sq <= (ycoord >> 4) * (ycoord >> 4);
        zcoord_sq <= (zcoord >> 4) * (zcoord >> 4);
        depth_buffer[0] <= xcoord_sq + ycoord_sq + zcoord_sq;
        new_triangle_buffer[0] <= new_triangle_in;

        for(int i = 0; i < 17; i = i+1) begin
            new_triangle_buffer[i+1] <= new_triangle_buffer[i];
        end

        for(int i = 0; i < 15; i = i+1) begin
            depth_buffer[i+1] <= depth_buffer[i];
        end
        final_depth <= depth_buffer[15] + depth_buffer[14] + depth_buffer[13];

        x_division_results[2] <= x_division_results[1];
        x_division_results[1] <= x_division_results[0];
        y_division_results[2] <= y_division_results[1];
        y_division_results[1] <= y_division_results[0];

    end


    
endmodule

`default_nettype wire