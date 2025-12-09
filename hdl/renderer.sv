`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../data/X`"
`endif  /* ! SYNTHESIS */

// one module to rule them all
module renderer(
    input wire clk,
    input wire rst,

    // when active is LOW, you can input triangles into this module
    input wire active,
    
    input wire [159:0] triangle,
    input wire triangle_valid,

    output logic [10:0] h_count, // not outputted in order!!!
    output logic [9:0] v_count,
    output logic valid,
    output logic last, // if the h_count, v_count are the last of their frame.
    output logic [15:0] data,

    output logic done
);

    localparam MAX_TRIANGLES = 256;
    localparam wMAX_TRIANGLES = $clog2(MAX_TRIANGLES);

    // ripping 16 way parallelization XD
    localparam N_WAY_PARALLEL = 16;
    localparam wN_WAY = $clog2(N_WAY_PARALLEL);

    //////////////////////////////////////// TRIANGLE BRAMS ////////////////////////////////////////////

    logic [wMAX_TRIANGLES-1:0] num_triangles;

    logic [wMAX_TRIANGLES-1:0] bram_triangle_in_addr;
    logic [159:0] bram_triangle_in_data;
    logic bram_triangle_in_valid;

    logic [wMAX_TRIANGLES-1:0] bram_triangle_out_addr [N_WAY_PARALLEL-1:0];
    logic [159:0] bram_triangle_out_data [N_WAY_PARALLEL-1:0];

    generate
        genvar i;
        for (i = 0; i < N_WAY_PARALLEL; i=i+1) begin
            xilinx_true_dual_port_read_first_2_clock_ram #(
                .RAM_WIDTH(160), //each triangle is 160 bits
                .RAM_DEPTH(MAX_TRIANGLES))
            triangle_bram (
                .addra(bram_triangle_in_addr), // a is for writing in triangles!
                .clka(clk),
                .wea(bram_triangle_in_valid),
                .dina(bram_triangle_in_data),
                .ena(1'b1),
                .regcea(1'b1),
                .rsta(rst),
                .douta(), //never read from this side
                .addrb(bram_triangle_out_addr[i]),// triangle lookup
                .dinb(160'b0),
                .clkb(clk),
                .web(1'b0),
                .enb(1'b1),
                .rstb(rst),
                .regceb(1'b1),
                .doutb(bram_triangle_out_data[i])
            );
        end
    endgenerate

    //////////////////////////////////////////////// TILE BRAMS ///////////////////////////////////////////

    // pixel to write into the tile BRAMs. Used by tile painter
    logic [9:0] tile_bram_pixel_in_addr [N_WAY_PARALLEL-1:0];
    logic tile_bram_pixel_in_valid [N_WAY_PARALLEL-1:0];
    logic [31:0] tile_bram_pixel_in_data [N_WAY_PARALLEL-1:0];

    // pixel to read out of the tile BRAMs. Used by BOTH TILE PAINTER AND DRAM WRITING!!!
    logic [9:0] tile_bram_pixel_out_addr [N_WAY_PARALLEL-1:0];
    logic [31:0] tile_bram_pixel_out_data [N_WAY_PARALLEL-1:0];

    generate
        genvar j;
        for (j = 0; j < N_WAY_PARALLEL; j=j+1) begin
            xilinx_true_dual_port_read_first_2_clock_ram #(
                .RAM_WIDTH(32), //each pixel is 32 bits - 16 bits of color, 16 bits of depth
                .RAM_DEPTH(800), // 80 x 10 tile
                .INIT_FILE(`FPATH(tile_bram.mem))
            ) tile_bram (
                .addra(tile_bram_pixel_in_addr[j]), // a is for writing in triangles!
                .clka(clk),
                .wea(tile_bram_pixel_in_valid[j]),
                .dina(tile_bram_pixel_in_data[j]),
                .ena(1'b1),
                .regcea(1'b1),
                .rsta(rst),
                .douta(), //never read from this side
                .addrb(tile_bram_pixel_out_addr[j]),// triangle lookup
                .dinb(32'b0),
                .clkb(clk),
                .web(1'b0),
                .enb(1'b1),
                .rstb(rst),
                .regceb(1'b1),
                .doutb(tile_bram_pixel_out_data[j])
            );
        end
    endgenerate

    /////////////////////////////////////////// TILE PAINTERS /////////////////////////////////////////

    typedef enum {
        RST,
        IDLE,
        PAINTING_TILES, // 2
        WRITING_TO_DRAM, // 3
        INTERMEDIATE_BEFORE_WIPE_1,
        INTERMEDIATE_BEFORE_WIPE_2,
        WIPING_TILES, // 6
        INTERMEDIATE_BEFORE_PAINTING_1,
        INTERMEDIATE_BEFORE_PAINTING_2,
        DONE
    } renderer_state;
    renderer_state state;

    logic [6:0] tile_index;
    // 80 x 10 in 1280 x 720
    // 16 way parallelization -> 1 row of tiles at once

    logic [9:0] y_offset;
    assign y_offset = tile_index * 10;

    logic tile_painters_active;
    logic tile_painters_wipe;

    logic [N_WAY_PARALLEL-1:0] tile_painters_done;

    logic [9:0] tile_painter_wants_to_read_tile_bram_addr [N_WAY_PARALLEL-1:0];

    generate
        genvar k;
        for (k = 0; k < N_WAY_PARALLEL; k=k+1) begin
            tile_painter #(.MAX_TRIANGLES(MAX_TRIANGLES)) tile_painter_inst (
                .clk(clk),
                .rst(rst),

                .active(tile_painters_active),
                .wipe(tile_painters_wipe),
                
                .num_triangles(num_triangles),
                .x_offset(k * 80),
                .y_offset(y_offset),

                .bram_triangle_read_data(bram_triangle_out_data[k]),
                .tile_bram_read_data(tile_bram_pixel_out_data[k]),

                .bram_triangle_read_addr(bram_triangle_out_addr[k]),
                .tile_bram_read_addr(tile_painter_wants_to_read_tile_bram_addr[k]),

                .tile_bram_write_addr(tile_bram_pixel_in_addr[k]),
                .tile_bram_write_valid(tile_bram_pixel_in_valid[k]),
                .tile_bram_write_data(tile_bram_pixel_in_data[k]),

                .done(tile_painters_done[k])
            );
        end
    endgenerate

    ////////////////////////////////////////////// FSM //////////////////////////////////////////////////

    logic [10:0] h_count_state;
    logic [6:0] h_count_modulo_80;
    logic [3:0] h_count_div_80;
    logic [9:0] v_count_state;
    logic [5:0] v_count_minus_offset;
    logic valid_state;

    logic [9:0] dram_wants_to_read_addr;

    assign dram_wants_to_read_addr = v_count_minus_offset * 80 + h_count_modulo_80;

    always_comb begin
        for (int l = 0; l < N_WAY_PARALLEL; l=l+1) begin
            tile_bram_pixel_out_addr[l] = (state == WRITING_TO_DRAM) ? dram_wants_to_read_addr : tile_painter_wants_to_read_tile_bram_addr[l];
        end
    end

    pipeline #(.WIDTH(11), .STAGES_NEEDED(2)) h_count_pl (
        .clk(clk),
        .in(h_count_state),
        .out(h_count)
    );

    pipeline #(.WIDTH(10), .STAGES_NEEDED(2)) v_count_pl (
        .clk(clk),
        .in(v_count_state),
        .out(v_count)
    );

    pipeline #(.WIDTH(1), .STAGES_NEEDED(2)) valid_pl (
        .clk(clk),
        .in(valid_state),
        .out(valid)
    );

    logic [3:0] h_count_div_80_pl;
    pipeline #(.WIDTH(4), .STAGES_NEEDED(2)) hcountdiv80_pl (
        .clk(clk),
        .in(h_count_div_80),
        .out(h_count_div_80_pl)
    );

    assign last = (h_count == 1279) && (v_count == 719);
    assign data = tile_bram_pixel_out_data[h_count_div_80_pl][31:16];

    logic piss_counter; // can only output data every 2 cycles cuz dram is a pissbaby

    always_ff @( posedge clk ) begin
        bram_triangle_in_valid <= 0;
        done <= 0;

        if(rst) begin
            state <= RST;
        end else if (state == RST) begin
            tile_painters_active <= 0;
            tile_painters_wipe <= 0;
            state <= IDLE;
            num_triangles <= 0;
            valid_state <= 0;
            piss_counter <= 0;
        end else if (state == IDLE) begin
            bram_triangle_in_addr <= num_triangles;
            bram_triangle_in_valid <= triangle_valid;
            bram_triangle_in_data <= triangle;

            if(triangle_valid) begin
                num_triangles <= num_triangles + 1;
            end

            if(active) begin
                state <= PAINTING_TILES;
                tile_painters_active <= 1;
                tile_index <= 0;
            end
        end else if (state == PAINTING_TILES) begin
            
            if (tile_painters_done == 16'hFFFF) begin
                // all tile painters done!
                state <= WRITING_TO_DRAM;
                h_count_state <= 0;
                v_count_state <= y_offset;
                v_count_minus_offset <= 0;
                h_count_modulo_80 <= 0;
                h_count_div_80 <= 0;
                valid_state <= 1;
            end
        end else if(state == WRITING_TO_DRAM) begin
            
            piss_counter <= !piss_counter;

            if(piss_counter == 0) begin 

                valid_state <= 1;
            
                if (h_count_modulo_80 < 79) begin
                    h_count_modulo_80 <= h_count_modulo_80 + 1;
                end else begin
                    h_count_modulo_80 <= 0;
                    h_count_div_80 <= h_count_div_80 + 1; // wraparounds automatically cuz 4 bits
                end

                if (h_count_state < 1279) begin
                    h_count_state <= h_count_state + 1;
                end else begin
                    h_count_state <= 0;

                    if (v_count_minus_offset < 9) begin
                        v_count_state <= v_count_state + 1;
                        v_count_minus_offset <= v_count_minus_offset + 1;
                    end else begin
                        state <= INTERMEDIATE_BEFORE_WIPE_1;
                        v_count_state <= 0;
                        v_count_minus_offset <= 0;
                        valid_state <= 0;

                        tile_painters_wipe <= 1;
                    end
                end

            end else begin
                valid_state <= 0;
            end
        end else if (state == INTERMEDIATE_BEFORE_WIPE_1) begin
            state <= INTERMEDIATE_BEFORE_WIPE_2; // have to have this state b/c tile_painters_done is still high.
        end else if (state == INTERMEDIATE_BEFORE_WIPE_2) begin
            state <= WIPING_TILES;
        end else if(state == WIPING_TILES) begin
            if(tile_painters_done == 16'hFFFF) begin
                
                tile_painters_wipe <= 0;

                if(tile_index == 71) begin
                    // we r sooo done
                    state <= DONE;
                end else begin
                    state <= INTERMEDIATE_BEFORE_PAINTING_1;
                    tile_index <= tile_index+1;
                    tile_painters_active <= 0;
                end

            end
        end else if(state == INTERMEDIATE_BEFORE_PAINTING_1) begin
            state <= INTERMEDIATE_BEFORE_PAINTING_2;
            tile_painters_active <= 1;
        end else if(state == INTERMEDIATE_BEFORE_PAINTING_2) begin
            state <= PAINTING_TILES;
        end else if(state == DONE) begin
            if (!active) begin
                state <= RST;
            end

            done <= 1;
        end
    end

endmodule


`default_nettype wire
