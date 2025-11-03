
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/ca9ffb7ecfc64884b39259f6cbfdae38/sim_build/tile_painter.fst");
    $dumpvars(0,tile_painter);
  end
endmodule
