`timescale 1ns / 1ps
`default_nettype none
// 18 cycle projection module.
// 16 cycles are due to division, 2 more for getting all 3 vertices out
// we get a vertex inputs which are still (0,0) at center of screen, so need to offset
// all coordinates by (WIDTH/2, HEIGHT/2).
module ddd_projector #(
        parameter LOG_D = 8, // this same parameter is in depth_calculator. Do not change either without changing the other.
        parameter WIDTH = 1280,
        parameter HEIGHT = 720
    )(
        input wire clk,
        input wire rst,
        input wire [47:0] vertex,
        input wire [15:0] color,
        input wire new_triangle_in, // high once at beginning of triangle
        input wire done_in, // done feeding all triangles
        output logic [159:0] triangle, // color|p1x|p1y|p2x|p2y|p3x|p3y|p(24)|nx|ny|nz(8)
        output logic new_triangle_out,
        output logic done_out
    );

    logic [15:0] color_out; // stores color to output after waiting 18 cycles for division/vertex collection
    logic [15:0] xcoord, ycoord, zcoord; // extracting unsigned coordinate data from vertex
    logic [23:0] xcoordz0, ycoordz0; // multiplying by plane we project onto
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

    logic [3:0] xcoordz0_right; // how much xcoordz0 should be bitshifted right to fit in 16 bits
    logic [3:0] ycoordz0_right;
    
    always_comb begin
        xcoordz0_right = 0;
        ycoordz0_right = 0;
        for (int i = 23; i >= 16; i=i-1) begin
            if(xcoordz0[i]) begin
                xcoordz0_right = i-15;
                break;
            end
        end
        for (int j = 23; j >= 16; j=j-1) begin
            if(ycoordz0[j]) begin
                ycoordz0_right = j-15;
                break;
            end
        end
    end

    logic [15:0] xcoord_dividend, ycoord_dividend;
    logic [15:0] zcoord_divisor_x, zcoord_divisor_y;
    
    assign xcoord_dividend = xcoordz0 >> xcoordz0_right;
    assign zcoord_divisor_x = zcoord >> xcoordz0_right;

    assign ycoord_dividend = ycoordz0 >> ycoordz0_right;
    assign zcoord_divisor_y = zcoord >> ycoordz0_right;

    divider3 #(.WIDTH(16)) xcoord_divider (
        .clk(clk),
        .rst(rst),
        .dividend_in(xcoord_dividend),
        .divisor_in(zcoord_divisor_x),
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
        .dividend_in(ycoord_dividend),
        .divisor_in(zcoord_divisor_y),
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
            triangle = {color_out, x_division_results[2], y_division_results[2], x_division_results[1], y_division_results[1], x_division_results[0], y_division_results[0], p_out, cx_out, cy_out, cz_out};
        end else begin
            triangle = 0;
        end
    end

    logic signed [15:0] v1x, v1y, v1z;
    logic signed [15:0] v1x_1, v1y_1, v1z_1; // these values must be pipelined

    logic signed [15:0] ax, ay, az, bx, by, bz;
    logic [1:0] new_triangle_state; // cycles since new triangle

    logic signed [19:0] cx_raw, cy_raw, cz_raw, cx_raw_1, cy_raw_1, cz_raw_1; // don't need 32 bits for this, x y coords are usually kinda smol

    logic [4:0] logcx, logcy, logcz;
    log2 xlog (
        .clk(clk),
        .c(cx_raw),
        .e(logcx)
    );
    log2 ylog (
        .clk(clk),
        .c(cy_raw),
        .e(logcy)
    );
    log2 zlog (
        .clk(clk),
        .c(cz_raw),
        .e(logcz)
    );
    logic [4:0] big_log;
    // assign big_log = (logcx > logcz && logcx > logcy) ? logcx : ((logcy > logcz) ? logcy : logcz);

    logic [4:0] cshift;
    assign cshift = (big_log > 7) ? big_log - 7 : 0;

    logic signed [7:0] cx, cy, cz;

    logic signed [23:0] p_x, p_y, p_z;
    logic [23:0] c_int;

    logic signed [23:0] p;
    logic [23:0] c;

    logic [47:0] pc;
    assign pc = {p, c};

    logic [47:0] pc_out;

    logic [23:0] p_out;
    logic [7:0] cx_out, cy_out, cz_out;
    assign p_out = pc_out[47:24];
    assign cx_out = pc_out[23:16];
    assign cy_out = pc_out[15:8];
    assign cz_out = pc_out[7:0];

    pipeline #(.WIDTH(48), .STAGES_NEEDED(10)) pc_pipeline (
        .clk(clk),
        .in(pc),
        .out(pc_out)
    );

    always_ff @(posedge clk) begin

        if (new_triangle_in) begin
            v1x <= vertex[47:32];
            v1y <= vertex[31:16];
            v1z <= vertex[15:0];
            new_triangle_state <= 1;
        end else if (new_triangle_state == 1) begin
            ax <= v1x - $signed(vertex[47:32]);
            ay <= v1y - $signed(vertex[31:16]);
            az <= v1z - $signed(vertex[15:0]);

            new_triangle_state <= 2;
        end else if (new_triangle_state == 2) begin
            bx <= v1x - $signed(vertex[47:32]);
            by <= v1y - $signed(vertex[31:16]);
            bz <= v1z - $signed(vertex[15:0]);

            new_triangle_state <= 3;
        end

        if (new_triangle_state == 3) begin 
            v1x_1 <= v1x;
            v1y_1 <= v1y;
            v1z_1 <= v1z;
        end

        // cx_raw <= ay * (bz >> 4) - (az >> 4) * by;
        // cy_raw <= (az >> 4) * bx - ax * (bz >> 4);
        // cz_raw <= (ax >> 2) * (by >> 2) - (ay >> 2) * (bx >> 2);

        cx_raw <= (ay * bz - az * by) >>> 4;
        cy_raw <= (az * bx - ax * bz) >>> 4;
        cz_raw <= (ax * by - ay * bx) >>> 4;

        cx_raw_1 <= cx_raw;
        cy_raw_1 <= cy_raw;
        cz_raw_1 <= cz_raw;
        big_log <= (logcx > logcz && logcx > logcy) ? logcx : ((logcy > logcz) ? logcy : logcz);

        cx <= cx_raw_1 >>> cshift;
        cy <= cy_raw_1 >>> cshift;
        cz <= cz_raw_1 >>> cshift;

        p_x <= cx * v1x_1;
        p_y <= cy * v1y_1;
        p_z <= cz * v1z_1;
        c_int <= {cx, cy, cz};

        p <= p_x + p_y + p_z;
        c <= c_int;

        new_triangle_buffer[0] <= new_triangle_in;

        for(int i = 0; i < 17; i = i+1) begin
            new_triangle_buffer[i+1] <= new_triangle_buffer[i];
        end

        x_division_results[2] <= x_division_results[1];
        x_division_results[1] <= x_division_results[0];
        y_division_results[2] <= y_division_results[1];
        y_division_results[1] <= y_division_results[0];

    end


    
endmodule

`default_nettype wire