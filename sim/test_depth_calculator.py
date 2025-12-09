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

    ## test some pixel insertions
    await ClockCycles(dut.clk, 3)

    """ 
    input wire clk,
    input wire [159:0] triangle, // color|p1x|p1y|p2x|p2y|p3x|p3y|P(24)|nx(8)|ny(8)|nz(8)
    input wire [10:0] x_coord,
    input wire [9:0] y_coord,
    output wire [15:0] depth,

    """
    
    # flat triangle at z = 50. Should always output depth 50
    dut.triangle.value = 0x003f0319023402e6023403b3019b000384000012
    dut.x_coord.value = 10
    dut.y_coord.value = 10

    await ClockCycles(dut.clk, 1)

    dut.triangle.value = 0x003f0319023402e6023403b3019b000384000012
    dut.x_coord.value = 1279
    dut.y_coord.value = 719
    
    await ClockCycles(dut.clk, 1)

    dut.triangle.value = 0x003f027f016702800168027f0167ffe124b1b1b1
    dut.x_coord.value = 100
    dut.y_coord.value = 100

    await ClockCycles(dut.clk, 100)


    # # wait 2 clock cycles then start doing a new triangle, with negative coordinates
    # await ClockCycles (dut.clk, 2)
    # dut.vertex.value = convert_to_vertex(30, 40, 50)
    # dut.color.value = 10
    # dut.new_triangle_in.value = 1
    # dut.done_in.value = 0

    # await ClockCycles(dut.clk, 1)
    # dut.vertex.value = convert_to_vertex((2**16 - 20), (2**16 - 64), 17)
    # dut.color.value = 10
    # dut.new_triangle_in.value = 0
    # dut.done_in.value = 0

    # await ClockCycles(dut.clk, 1)
    # dut.vertex.value = convert_to_vertex(60, (2**16 - 170), 10)
    # dut.color.value = 10
    # dut.new_triangle_in.value = 0
    # dut.done_in.value = 0

    await ClockCycles(dut.clk, 20)


def depth_calculator_runner():
    """3D Projector Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    # sim = os.getenv("SIM", "icarus")
    sim = os.getenv("SIM","vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "depth_calculator.sv", proj_path / "hdl" / "pipeline.sv", proj_path / "hdl" / "divider3.sv", proj_path / "hdl" / "small_multiplier.sv"]
    build_test_args = ["-Wall"]
    #values for parameters defined earlier in the code.
    # parameters = { 'KERNEL_DIMENSION': 3, 'K_SELECT': 2} # sharpen for now
 
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "depth_calculator"
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
    depth_calculator_runner()