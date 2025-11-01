
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/4f73175733e04f3c8a8e0c5365f302c6/sim_build/tile_painter.fst");
    $dumpvars(0,tile_painter);
  end
endmodule
