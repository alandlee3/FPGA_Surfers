
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/a34b14f31c994be9a93778f8bcd2810e/sim_build/pixel_calculator.fst");
    $dumpvars(0,pixel_calculator);
  end
endmodule
