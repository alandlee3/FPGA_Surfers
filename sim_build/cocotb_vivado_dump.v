
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/878d435a1aa24469b33a79a5e1ebe788/sim_build/tile_painter.fst");
    $dumpvars(0,tile_painter);
  end
endmodule
