
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/d5416c626c8e434c9689884e824ee848/sim_build/tile_painter.fst");
    $dumpvars(0,tile_painter);
  end
endmodule
