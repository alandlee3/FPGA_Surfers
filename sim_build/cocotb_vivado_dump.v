
`timescale 1ns / 1ps
module cocotb_vivado_dump();
  initial begin
    $dumpfile("/home/fpga/worker_place/temp/temp/4a2417e1e47d4e13971aaae2e9e42261/sim_build/ddd_projector.fst");
    $dumpvars(0,ddd_projector);
  end
endmodule
