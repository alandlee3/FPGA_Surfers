`timescale 1ns / 1ps
`default_nettype none


module tile_painter #(parameter MAX_TRIANGLES=256) (
       input wire clk,
       input wire rst,


       // when active is high, this module will start going through all the triangles in the triangle bram
       // and modify all the pixels in the tile bram.
       input wire active,
      
       // when wipe is high, the module will begin wiping if it is in the DONE or RST state.
       input wire wipe,


       input wire [$clog2(MAX_TRIANGLES)-1:0] num_triangles,
       input wire [10:0] x_offset, // x coord of the top left pixel of the current tile
       input wire [9:0] y_offset, // y coord **


       input wire [159:0] bram_triangle_read_data, // recall this is 2 cycles delayed from bram_triangle_read_addr
       input wire [31:0] tile_bram_read_data, // 2 cycles delayed from tile_bram_read_addr


       output logic [$clog2(MAX_TRIANGLES)-1:0] bram_triangle_read_addr,
       output logic [9:0] tile_bram_read_addr,


       output logic [9:0] tile_bram_write_addr,
       output logic tile_bram_write_valid,
       output logic [31:0] tile_bram_write_data,
      
       // done will be held high after the operation is completed
       output logic done
	);
	localparam TRIANGLE_BRAM_ADDR_WIDTH = $clog2(MAX_TRIANGLES);


	logic [6:0] x_offset_reading;
	logic [3:0] y_offset_reading;
	logic [10:0] x_coord_reading; // x_coord = x_offset_reading + x_offset
	logic [9:0] y_coord_reading;
	
	logic [10:0] x_coord_calculating;
	logic [9:0] y_coord_calculating;
	logic [6:0] x_offset_writing;
	logic [3:0] y_offset_writing;


	logic reading_coords_valid;
	logic calculating_coords_valid;
	logic writing_coords_valid;

	logic [31:0] writing_pixel_data;

	// 2 cycles for bram getting data, 27 cycles for depth calculation
	pipeline #(.WIDTH(7), .STAGES_NEEDED(29)) x_offset_pl_inst (
		.clk(clk),
		.in(x_offset_reading),
		.out(x_offset_writing)
	);

	pipeline #(.WIDTH(4), .STAGES_NEEDED(29)) y_offset_pl_inst (
		.clk(clk),
		.in(y_offset_reading),
		.out(y_offset_writing)
	);

	assign x_coord_reading = x_offset + x_offset_reading;
	assign y_coord_reading = y_offset + y_offset_reading;


	pipeline #(.WIDTH(11), .STAGES_NEEDED(2)) x_coord_pl_inst (
		.clk(clk),
		.in(x_coord_reading),
		.out(x_coord_calculating)
	);


	pipeline #(.WIDTH(10), .STAGES_NEEDED(2)) y_coord_pl_inst (
		.clk(clk),
		.in(y_coord_reading),
		.out(y_coord_calculating)
	);


	pipeline #(.WIDTH(1), .STAGES_NEEDED(2)) tile_reading_to_calc_valid_pl_inst (
		.clk(clk),
		.in(reading_coords_valid),
		.out(calculating_coords_valid)
	);


	logic [159:0] triangle_data;
	logic [TRIANGLE_BRAM_ADDR_WIDTH-1:0] triangle_index;

	logic [8:0] x_wipe;
	logic [7:0] y_wipe;

	assign bram_triangle_read_addr = triangle_index;


	typedef enum {
		RST,
		READING_NEW_TRIANGLE_1, // reading a new triangle from BRAMs, first cycle
		READING_NEW_TRIANGLE_2, // reading a new triangle from BRAMs, second cycle
		DONE_READING_TRIANGLE, // done reading new triangle, find triangle data and go to iteration.
		CALCULATING_BOUNDS, // extra clock cycle to calculate bounding box stuff
		ITERATING, // x_offset_reading, y_offset_reading are cycling.
		WAITING, // waiting for the calculation pipeline to complete...
		DONE, // done painting !!
		WIPE, // currently wiping !!
		WIPEDONE // done wiping, nothing will get you out of this state except holding active low.
	} tile_state_type;
	tile_state_type tile_state;

	logic pixel_inside_cycle_1;
	logic calculating_valid_cycle_1;
	// 1 cycle calculation of whether the pixel is inside
	pixel_calculator pixel_calculator_inst(
		.clk(clk),
		.rst(rst),
		.xcoord_in(x_coord_calculating),
		.ycoord_in(y_coord_calculating),
		//    .pixel_data_in(tile_bram_read_data),
		.triangle(triangle_data),
		.pixel_in_valid(calculating_coords_valid),
		.xcoord_out(),
		.ycoord_out(),
		.pixel_out_valid(calculating_valid_cycle_1),
		//    .pixel_data_out(writing_pixel_data)
		.pixel_inside(pixel_inside_cycle_1)
	);

	logic writing_pixel_inside_and_valid;
	pipeline #(.WIDTH(1), .STAGES_NEEDED(26)) pixel_valid_pl_inst (
		.clk(clk),
		.in(pixel_inside_cycle_1 && calculating_valid_cycle_1),
		.out(writing_pixel_inside_and_valid)
	);

	logic [15:0] pipelined_pixel_depth;
	pipeline #(.WIDTH(32), .STAGES_NEEDED(27)) big_fat_pixel_data_pipeline (
		.clk(clk),
		.in(tile_bram_read_data[15:0]),
		.out(pipelined_pixel_depth)
	);

	assign writing_coords_valid = writing_pixel_inside_and_valid && (pipelined_pixel_depth > triangle_depth);
	assign writing_pixel_data = { triangle_data[159:144], triangle_depth };

	logic [15:0] triangle_depth;
	// 27 cycle pipelined calculation of triangle depth

	logic signed [11:0] x_coord_calculating_centered;
	logic signed [10:0] y_coord_calculating_centered;

	assign x_coord_calculating_centered = $signed(x_coord_calculating) - 640;
	assign y_coord_calculating_centered = $signed(y_coord_calculating) - 360;
	

	depth_calculator depth_calculator_inst(
		.clk(clk),
		.triangle(triangle_data),
		.x_coord(x_coord_calculating_centered),
		.y_coord(y_coord_calculating_centered),
		.depth(triangle_depth)
	);


	assign tile_bram_write_addr = (tile_state == WIPE) ? (y_wipe * 80 + x_wipe) : (y_offset_writing * 80 + x_offset_writing);
	assign tile_bram_write_data = (tile_state == WIPE) ? 32'hFFFFFFFF : writing_pixel_data;
	assign tile_bram_write_valid = (tile_state == WIPE) ? 1 : writing_coords_valid;


	assign tile_bram_read_addr = y_offset_reading * 80 + x_offset_reading;


	logic [6:0] x_offset_lower_bound, y_offset_lower_bound, x_offset_upper_bound, y_offset_upper_bound;
	logic signed [15:0] max_x, min_x, max_y, min_y;
	logic signed [15:0] p1x, p1y, p2x, p2y, p3x, p3y;
	assign p1x = $signed(bram_triangle_read_data[111:96]);
	assign p1y = $signed(bram_triangle_read_data[95:80]);
	assign p2x = $signed(bram_triangle_read_data[79:64]);
	assign p2y = $signed(bram_triangle_read_data[63:48]);
	assign p3x = $signed(bram_triangle_read_data[143:128]);
	assign p3y = $signed(bram_triangle_read_data[127:112]);
	logic no_intersection;


	// bounding box of triangle calculations
	assign max_x = (p1x >= p2x && p1x >= p3x) ? p1x : (p2x >= p3x) ? p2x : p3x;
	assign max_y = (p1y >= p2y && p1y >= p3y) ? p1y : (p2y >= p3y) ? p2y : p3y;
	assign min_x = (p1x <= p2x && p1x <= p3x) ? p1x : (p2x <= p3x) ? p2x : p3x;
	assign min_y = (p1y <= p2y && p1y <= p3y) ? p1y : (p2y <= p3y) ? p2y : p3y;

	logic signed [11:0] x_offset_s;
	logic signed [10:0] y_offset_s;

	assign x_offset_s = {1'b0, x_offset};
	assign y_offset_s = {1'b0, y_offset};

	logic [4:0] waiting_cycle; // we wait 30 cycles for calculation to finish up

	always_ff @( posedge clk ) begin
		
		done <= 0;


		if ( !active || rst) begin
			tile_state <= RST;


			reading_coords_valid <= 0;
		end else if (tile_state == RST) begin
			reading_coords_valid <= 0;
			
			if (wipe) begin // wipe takes priority!
				tile_state <= WIPE;
				x_wipe <= 0;
				y_wipe <= 0;
			end else if (active) begin
				if(num_triangles == 0) begin
					tile_state <= DONE;
				end else begin
					triangle_index <= 0;
					tile_state <= READING_NEW_TRIANGLE_1;
				end
			end
		end else if (tile_state == READING_NEW_TRIANGLE_1) begin
			tile_state <= READING_NEW_TRIANGLE_2;
		end else if(tile_state == READING_NEW_TRIANGLE_2) begin
			tile_state <= DONE_READING_TRIANGLE;
		end else if(tile_state == DONE_READING_TRIANGLE) begin
			// we have a new triangle! initialize the ITERATING state.
			triangle_data <= bram_triangle_read_data;


			// calculate for specific tile which bounds to use
			x_offset_lower_bound <= ($signed(min_x) <= x_offset_s) ? 0 : ($signed(min_x) >= x_offset_s + 80) ? 80 : $signed(min_x) - x_offset_s;
			y_offset_lower_bound <= ($signed(min_y) <= y_offset_s) ? 0 : ($signed(min_y) >= y_offset_s + 10) ? 10 : $signed(min_y) - y_offset_s;
			x_offset_upper_bound <= ($signed(max_x) >= x_offset_s + 80) ? 80 : ($signed(max_x) <= x_offset_s) ? 0 : $signed(max_x) - x_offset_s;
			y_offset_upper_bound <= ($signed(max_y) >= y_offset_s + 10) ? 10 : ($signed(max_y) <= y_offset_s) ? 0 : $signed(max_y) - y_offset_s;


			// compute if there's no intersection at all, too
			no_intersection <=  ($signed(min_x) >= x_offset_s + 80) ||
								($signed(max_x) <= x_offset_s) ||
								($signed(min_y) >= y_offset_s + 10) ||
								($signed(max_y) <= y_offset_s);


			tile_state <= CALCULATING_BOUNDS;
		end else if (tile_state == CALCULATING_BOUNDS) begin
			if (no_intersection) begin
				// done with current triangle!
				reading_coords_valid <= 0;


				if (triangle_index + 1 < num_triangles) begin
					triangle_index <= triangle_index + 1;
					tile_state <= READING_NEW_TRIANGLE_1;
				end else begin
					// we are fully done with all triangles.
					tile_state <= DONE;
				end
			end else begin
				tile_state <= ITERATING;
				x_offset_reading <= x_offset_lower_bound;
				y_offset_reading <= y_offset_lower_bound;
				reading_coords_valid <= 1;
			end
		end else if (tile_state == ITERATING) begin
			// must cycle x_offset_reading from 0 to end of intersection - 1
			if (x_offset_reading < x_offset_upper_bound - 1) begin
				x_offset_reading <= x_offset_reading + 1;
			end else begin
				x_offset_reading <= x_offset_lower_bound;


				// must cycle y_offset_reading from 0 to end of intersection - 1
				if (y_offset_reading < y_offset_upper_bound - 1) begin
					y_offset_reading <= y_offset_reading + 1;
				end else begin
					// done with current triangle!
					reading_coords_valid <= 0;

					tile_state <= WAITING;
					waiting_cycle <= 0;
				end
			end
		end else if(tile_state == WAITING) begin
			waiting_cycle <= waiting_cycle + 1;

			if (waiting_cycle == 29) begin
			
				if (triangle_index + 1 < num_triangles) begin
					triangle_index <= triangle_index + 1;
					tile_state <= READING_NEW_TRIANGLE_1;
				end else begin
					// we are fully done with all triangles.
					tile_state <= DONE;
				end

			end
		end else if(tile_state == DONE) begin
			done <= 1;


			if (wipe) begin
				tile_state <= WIPE;
				x_wipe <= 0;
				y_wipe <= 0;
			end
		end else if(tile_state == WIPE) begin
			if (x_wipe < 79) begin
				x_wipe <= x_wipe + 1;
			end else begin
				x_wipe <= 0;


				// must cycle y_offset_reading from 0 to 9
				if (y_wipe < 9) begin
					y_wipe <= y_wipe + 1;
				end else begin
					tile_state <= WIPEDONE;
				end
			end
		end else if (tile_state == WIPEDONE) begin
			done <= 1;
		end
	end


	endmodule


`default_nettype wire

