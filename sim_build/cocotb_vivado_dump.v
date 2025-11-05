
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/e25111aa5cc5494d81746455112089ff/sim_build/tile_painter.fst");
    $dumpvars(0,tile_painter);
  end
endmodule
