import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
# from cocotb.runner import get_runner
from vicoco.vivado_runner import get_runner
test_file = os.path.basename(__file__).replace(".py","")

CLK_PERIOD = 10
PCLK_PERIOD = 20

@cocotb.test()
async def test_a(dut):
    """cocotb test"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units="ns").start())
    # cocotb.start_soon(Clock(dut.camera_pclk, PCLK_PERIOD, units="ns").start())

    dut._log.info("Holding reset...")
    dut.rst.value = 1

    ## test some pixel insertions
    await ClockCycles(dut.clk, 3)
    dut.rst.value = 0

    # input wire clk,
    # input wire rst,
    # input wire [8:0] xcoord_in,
    # input wire [7:0] ycoord_in,
    # input wire [31:0] pixel_data_in, // top 16 bits color, bottom 16 bits depth
    # input wire [127:0] triangle, // color|p1x|p1y|p2x|p2y|p3x|p3y|p1z+p2z+p3z, depth unsigned
    # input wire pixel_in_valid,
    # output logic [8:0] xcoord_out,
    # output logic [7:0] ycoord_out,
    # output logic [31:0] pixel_data_out, // top 16 bits color, bottom 16 bits depth
    # output logic pixel_out_valid

    def convert_to_triangle(color, p1x, p1y, p2x, p2y, p3x, p3y, total_depth):
        return color * (2**112) + p1x * (2**96) + p1y * (2**80) + p2x * (2**64) + p2y * (2**48) + p3x * (2**32) + p3y * (2**16) + total_depth

    await ClockCycles(dut.clk, 1)
    dut.xcoord_in.value = 10
    dut.ycoord_in.value = 15
    dut.pixel_data_in.value = 57005 * (2**16) + 48879 # deadbeef
    dut.triangle.value = convert_to_triangle(57069, 1, 1, 35, 80, 17, 10, 15)
    dut.pixel_in_valid.value = 1

    # move triangle to make pixel not inside, also vary depth (but still behind)
    await ClockCycles(dut.clk, 1)
    dut.xcoord_in.value = 10
    dut.ycoord_in.value = 15
    dut.pixel_data_in.value = 57005 * (2**16) + 16
    dut.triangle.value = convert_to_triangle(57069, 10, 10, 35, 80, 17, 10, 15)
    dut.pixel_in_valid.value = 1

    # move triangle to contain again, but with negative coords
    await ClockCycles(dut.clk, 1)
    dut.xcoord_in.value = 10
    dut.ycoord_in.value = 15
    dut.pixel_data_in.value = 57005 * (2**16) + 48879 # deadbeef
    dut.triangle.value = convert_to_triangle(57069, 2**16 - 150, 2**16 - 10, 35, 80, 17, 10, 15)
    dut.pixel_in_valid.value = 1

    # still in triangle, but now closer to screen
    await ClockCycles(dut.clk, 1)
    dut.xcoord_in.value = 10
    dut.ycoord_in.value = 15
    dut.pixel_data_in.value = 57005 * (2**16) + 10
    dut.triangle.value = convert_to_triangle(57069, 2**16 - 150, 2**16 - 10, 35, 80, 17, 10, 15)
    dut.pixel_in_valid.value = 1

    # still in triangle, but now tied for closeness (thus no update)
    await ClockCycles(dut.clk, 1)
    dut.xcoord_in.value = 10
    dut.ycoord_in.value = 15
    dut.pixel_data_in.value = 6767 * (2**16) + 15
    dut.triangle.value = convert_to_triangle(57069, 2**16 - 150, 2**16 - 10, 35, 80, 17, 10, 15)
    dut.pixel_in_valid.value = 1

    await ClockCycles(dut.clk, 3)

def pixel_calculator_runner():
    """Tile Painter Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    # sim = os.getenv("SIM", "icarus")
    sim = os.getenv("SIM","vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "pixel_calculator.sv"]
    build_test_args = ["-Wall"]
    #values for parameters defined earlier in the code.
    # parameters = { 'KERNEL_DIMENSION': 3, 'K_SELECT': 2} # sharpen for now
 
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "pixel_calculator"
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        # parameters = parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_file,
        test_args=run_test_args,
        waves=True
    )

if __name__ == '__main__':
    pixel_calculator_runner()