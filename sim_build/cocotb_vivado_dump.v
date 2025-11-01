
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/cea92d0c5f5e479e916e9d4489af9fa3/sim_build/tile_painter.fst");
    $dumpvars(0,tile_painter);
  end
endmodule
