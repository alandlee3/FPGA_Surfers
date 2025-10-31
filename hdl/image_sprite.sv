`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../data/X`"
`endif  /* ! SYNTHESIS */

module image_sprite #(
        parameter WIDTH=256, HEIGHT=256)
    (
        input wire pixel_clk,
        input wire rst,
        input wire [10:0] x, h_count,
        input wire [9:0]  y, v_count,
        output logic [7:0] pixel_red,
        output logic [7:0] pixel_green,
        output logic [7:0] pixel_blue
    );

    logic [10:0] h_count_pipe [3:0];
    logic [9:0] v_count_pipe [3:0];

    always_ff @(posedge pixel_clk)begin
        // PS10 (4 stages)
        h_count_pipe[0] <= h_count;
        v_count_pipe[0] <= v_count;
        for (int i=1; i<4; i = i+1)begin
            h_count_pipe[i] <= h_count_pipe[i-1];
            v_count_pipe[i] <= v_count_pipe[i-1];
        end
    end

  

    // calculate ROM address
    logic [$clog2(WIDTH*HEIGHT)-1:0] image_addr;
    assign image_addr = (h_count - x) + ((v_count - y) * WIDTH);

    logic [7:0] palette_addr;
    logic [23:0] palette_color;

    logic in_sprite;
    assign in_sprite = ((h_count_pipe[3] >= x && h_count_pipe[3] < (x + WIDTH)) &&
                        (v_count_pipe[3] >= y && v_count_pipe[3] < (y + HEIGHT)));

    // Modify the module below to use your BRAMs!
    // this will not do anything without you doing that!
    assign pixel_red =    in_sprite ? palette_color[23:16] : 0;
    assign pixel_green =  in_sprite ? palette_color[15:8] : 0;
    assign pixel_blue =   in_sprite ? palette_color[7:0] : 0;

    xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(8),                       // Specify RAM data width
    .RAM_DEPTH(65536),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(image.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
    ) image_instance (
    .addra(image_addr),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(palette_addr)      // RAM output data, width determined from RAM_WIDTH
  );

  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(24),                       // Specify RAM data width
    .RAM_DEPTH(256),                     // Specify RAM depth (number of entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(palette.mem))          // Specify name/location of RAM initialization file if using one (leave blank if not)
  ) palette_instance (
    .addra(palette_addr),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(palette_color)      // RAM output data, width determined from RAM_WIDTH
  );
endmodule






`default_nettype none
