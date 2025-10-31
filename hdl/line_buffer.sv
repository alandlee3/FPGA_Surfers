`default_nettype none
`timescale 1ns / 1ps
module line_buffer #(
    parameter KERNEL_SIZE = 3,
    parameter HRES = 1280,
    parameter VRES = 720
    )(
            input wire clk, //system clock
            input wire rst, //system reset

            input wire [10:0] h_count_in, //current h_count being read
            input wire [9:0] v_count_in, //current v_count being read
            input wire [15:0] pixel_data_in, //incoming pixel
            input wire data_in_valid, //incoming  valid data signal

            output logic [KERNEL_SIZE-1:0][15:0] line_buffer_out, //output pixels of data
            output logic [10:0] h_count_out, //current h_count being read
            output logic [9:0] v_count_out, //current v_count being read
            output logic data_out_valid //valid data out signal
  );


  // to help you get started, here's a bram instantiation.
  // you'll want to create one BRAM for each row in the kernel, plus one more to
  // buffer incoming data from the wire:
  // use v_count_in to decide which to write to and which others to read from
  logic [3:0] bram_write_enable;
  logic [3:0][15:0] bram_out;
  logic valid_buff;
  logic [10:0] h_count_buff;
  logic [9:0] v_count_buff;
  always_ff @(posedge clk) begin
    valid_buff <= data_in_valid;
    data_out_valid <= valid_buff;

    h_count_out <= h_count_buff;
    h_count_buff <= h_count_in;

    if (v_count_in == 0) begin
      v_count_buff <= VRES-2;
    end else if (v_count_in == 1) begin
      v_count_buff <= VRES-1;
    end else begin
      v_count_buff <= v_count_in - 2;
    end
    v_count_out <= v_count_buff;
  end

  always_comb begin
    if (data_in_valid) begin
      case(v_count_in[1:0])
        0: bram_write_enable = 4'b0001;
        1: bram_write_enable = 4'b0010;
        2: bram_write_enable = 4'b0100;
        3: bram_write_enable = 4'b1000;
      endcase
    end else begin
      bram_write_enable = 4'b0000;
    end

    if (data_out_valid) begin
      case(v_count_out[1:0]) // center here
        0: begin
          line_buffer_out[2] = bram_out[1];
          line_buffer_out[1] = bram_out[0];
          line_buffer_out[0] = bram_out[3];
        end
        1: begin
          line_buffer_out[2] = bram_out[2];
          line_buffer_out[1] = bram_out[1];
          line_buffer_out[0] = bram_out[0];
        end
        2: begin
          line_buffer_out[2] = bram_out[3];
          line_buffer_out[1] = bram_out[2];
          line_buffer_out[0] = bram_out[1];
        end
        3: begin
          line_buffer_out[2] = bram_out[0];
          line_buffer_out[1] = bram_out[3];
          line_buffer_out[0] = bram_out[2];
        end
      endcase
    end
  end

  generate
      genvar i;
      for (i=0; i<KERNEL_SIZE+1; i=i+1)begin
          xilinx_true_dual_port_read_first_1_clock_ram #(
          .RAM_WIDTH(16),
          .RAM_DEPTH(HRES),
          .RAM_PERFORMANCE("HIGH_PERFORMANCE")) line_buffer_ram (
          .clka(clk),     // Clock
          //writing port:
          .addra(h_count_in),   // Port A address bus,
          .dina(pixel_data_in),     // Port A RAM input data
          .wea(bram_write_enable[i]),       // Port A write enable
          //reading port:
          .addrb(h_count_in),   // Port B address bus,
          .doutb(bram_out[i]),    // Port B RAM output data,
          .douta(),   // Port A RAM output data, width determined from RAM_WIDTH
          .dinb(0),     // Port B RAM input data, width determined from RAM_WIDTH
          .web(1'b0),       // Port B write enable
          .ena(1'b1),       // Port A RAM Enable
          .enb(1'b1),       // Port B RAM Enable,
          .rsta(1'b0),     // Port A output reset
          .rstb(1'b0),     // Port B output reset
          .regcea(1'b1), // Port A output register enable
          .regceb(1'b1) // Port B output register enable
        );
      end
    endgenerate

endmodule


`default_nettype wire

