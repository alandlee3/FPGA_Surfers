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
    # input wire [47:0] vertex,
    # input wire [15:0] color,
    # input wire new_triangle_in, // high once at beginning of triangle
    # input wire done_in, // done feeding all triangles
    # output logic [127:0] triangle, // color|p1x|p1y|p2x|p2y|p3x|p3y|'depth'
    # output logic new_triangle_out,
    # output logic done_out,

    def convert_to_vertex(x, y, z):
        return x * (2**32) + y * (2**16) + z

    def convert_to_triangle(color, p1x, p1y, p2x, p2y, p3x, p3y, total_depth):
        return color * (2**112) + p1x * (2**96) + p1y * (2**80) + p2x * (2**64) + p2y * (2**48) + p3x * (2**32) + p3y * (2**16) + total_depth

    await ClockCycles(dut.clk, 1)
    dut.vertex.value = convert_to_vertex(30, 40, 50)
    dut.color.value = 63
    dut.new_triangle_in.value = 1
    dut.done_in.value = 0

    await ClockCycles(dut.clk, 1)
    dut.vertex.value = convert_to_vertex(20, 40, 70)
    dut.color.value = 63
    dut.new_triangle_in.value = 0
    dut.done_in.value = 0

    await ClockCycles(dut.clk, 1)
    dut.vertex.value = convert_to_vertex(60, 10, 10)
    dut.color.value = 63
    dut.new_triangle_in.value = 0
    dut.done_in.value = 0

    # wait 2 clock cycles then start doing a new triangle, with negative coordinates
    await ClockCycles (dut.clk, 2)
    dut.vertex.value = convert_to_vertex(30, 40, 50)
    dut.color.value = 10
    dut.new_triangle_in.value = 1
    dut.done_in.value = 0

    await ClockCycles(dut.clk, 1)
    dut.vertex.value = convert_to_vertex((2**16 - 20), (2**16 - 64), 17)
    dut.color.value = 10
    dut.new_triangle_in.value = 0
    dut.done_in.value = 0

    await ClockCycles(dut.clk, 1)
    dut.vertex.value = convert_to_vertex(60, (2**16 - 170), 10)
    dut.color.value = 10
    dut.new_triangle_in.value = 0
    dut.done_in.value = 0

    await ClockCycles(dut.clk, 20)


def ddd_projector_runner():
    """3D Projector Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    # sim = os.getenv("SIM", "icarus")
    sim = os.getenv("SIM","vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "ddd_projector.sv", proj_path / "hdl" / "pipeline.sv", proj_path / "hdl" / "divider3.sv"]
    build_test_args = ["-Wall"]
    #values for parameters defined earlier in the code.
    # parameters = { 'KERNEL_DIMENSION': 3, 'K_SELECT': 2} # sharpen for now
 
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "ddd_projector"
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
    ddd_projector_runner()