
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/ba42ef69a50c4174aa243a96919be8c6/sim_build/pixel_calculator.fst");
    $dumpvars(0,pixel_calculator);
  end
endmodule
