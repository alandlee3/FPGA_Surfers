`timescale 1ns / 1ps
`default_nettype none
module pixel_calculator (
        input wire clk,
        input wire rst,
        input wire [8:0] xcoord_in,
        input wire [7:0] ycoord_in,
        input wire [31:0] pixel_data_in, // top 16 bits color, bottom 16 bits depth
        input wire [127:0] triangle, // color|p1x|p1y|p2x|p2y|p3x|p3y|'depth', depth unsigned
        input wire pixel_in_valid,
        output logic [8:0] xcoord_out,
        output logic [7:0] ycoord_out,
        output logic [31:0] pixel_data_out, // top 16 bits color, bottom 16 bits depth
        output logic pixel_out_valid
    );

    // 1 stage pipeline
    
    // depth is unsigned, '0' corresponds to front of the screen

    // extract color and depth separately from pixel
    logic [15:0] color_data_in;
    logic [15:0] depth_data_in;
    assign color_data_in = pixel_data_in[31:16];
    assign depth_data_in = pixel_data_in[15:0];

    // extract triangle info
    logic [15:0] triangle_color;
    logic signed [15:0] p1x, p1y, p2x, p2y, p3x, p3y;
    logic [15:0] total_depth;
    assign triangle_color = triangle[127:112];
    assign p1x = $signed(triangle[111:96]);
    assign p1y = $signed(triangle[95:80]);
    assign p2x = $signed(triangle[79:64]);
    assign p2y = $signed(triangle[63:48]);
    assign p3x = $signed(triangle[47:32]);
    assign p3y = $signed(triangle[31:16]);
    assign total_depth = triangle[15:0];

    // compute vector components for each side vector
    logic signed [1:0][15:0] ab, bc, ca;
    assign ab[0] = p2x - p1x;// x coordinate
    assign ab[1] = p2y - p1y;// y coordinate
    assign bc[0] = p3x - p2x;// x coordinate
    assign bc[1] = p3y - p2y;// y coordinate
    assign ca[0] = p1x - p3x;// x coordinate
    assign ca[1] = p1y - p3y;// y coordinate

    // compute vector components for each pixel vector
    logic signed [1:0][15:0] ap, bp, cp;
    assign ap[0] = $signed(xcoord_in - p1x);
    assign ap[1] = $signed(ycoord_in - p1y);
    assign bp[0] = $signed(xcoord_in - p2x);
    assign bp[1] = $signed(ycoord_in - p2y);
    assign cp[0] = $signed(xcoord_in - p3x);
    assign cp[1] = $signed(ycoord_in - p3y);

    // cross product registers
    logic signed [31:0] c11, c12, c21, c22, c31, c32;

    // additional buffers for combinational logic
    logic [15:0] total_depth_buff, color_data_buff, depth_data_buff, triangle_color_buff;

    // check if pixel is in triangle AND triangle is closer to screen than last pixel triangle
    always_comb begin
        if (!rst) begin
            if ((total_depth_buff < depth_data_buff) && ((c11 - c12 >= 0 && c21 - c22 >= 0 && c31 - c32 >= 0) || (c11 - c12 <= 0 && c21 - c22 <= 0 && c31 - c32 <= 0))) begin
                pixel_data_out = {triangle_color_buff, total_depth_buff};
            end else begin
                pixel_data_out = {color_data_buff, depth_data_buff};
            end
        end else begin
            pixel_data_out = 0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            pixel_out_valid <= 0;
            xcoord_out <= 0;
            ycoord_out <= 0;
        end else begin
            // pipeline things properly
            pixel_out_valid <= pixel_in_valid;
            ycoord_out <= ycoord_in;
            xcoord_out <= xcoord_in;
            total_depth_buff <= total_depth;
            color_data_buff <= color_data_in;
            depth_data_buff <= depth_data_in;
            triangle_color_buff <= triangle_color;

            // multiplications for cross products
            c11 <= $signed(ab[0]) * $signed(ap[1]);
            c12 <= $signed(ab[1]) * $signed(ap[0]);
            c21 <= $signed(bc[0]) * $signed(bp[1]);
            c22 <= $signed(bc[1]) * $signed(bp[0]);
            c31 <= $signed(ca[0]) * $signed(cp[1]);
            c32 <= $signed(ca[1]) * $signed(cp[0]);
        end
    end
    

    
endmodule

`default_nettype wire



