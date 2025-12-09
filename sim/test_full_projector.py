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

def convert_to_triangle(color, p1x, p1y, p2x, p2y, p3x, p3y, total_depth):
    return color * (2**112) + p1x * (2**96) + p1y * (2**80) + p2x * (2**64) + p2y * (2**48) + p3x * (2**32) + p3y * (2**16) + total_depth

def convert_to_obstacle(type, lane, depth):
    return lane * (2**11) + type * (2**13) + depth

OBSTACLES = [ (4, 0, 128), (4, 1, 256), (4,1,128), (1, 2, 256) ]

@cocotb.test()
async def test_a(dut):
    """cocotb test"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units="ns").start())

    dut._log.info("Holding reset...")
    dut.rst.value = 1

    dut.obstacle_valid.value = 0
    dut.done_in.value = 0
    dut.obstacle.value = 0
    dut.player_height.value = 2**16-128
    dut.player_lane.value = 0

    await ClockCycles(dut.clk, 3)

    dut.rst.value = 0

    await ClockCycles(dut.clk, 3)

    for obstacle in OBSTACLES:
            
        dut.obstacle_valid.value = 1
        dut.obstacle.value = convert_to_obstacle(*obstacle)
        # dut.obstacle.value = obstacle

        await read_clock_cycle(dut)

        dut.obstacle_valid.value = 0

        for _ in range(30):
            await read_clock_cycle(dut)

    dut.done_in.value = 1

    for _ in range(200):
        await read_clock_cycle(dut)

    with open("test_projector_list.txt", "w") as file:
        file.write(str(triangles))

def p_int(str):
    if str == 'X':
        return 0
    else:
        try:
            return int(str)
        except:
            return 0

triangles = []

async def read_clock_cycle(dut):

    await FallingEdge(dut.clk)

    if p_int(dut.triangle_valid.value) == 1:
        triangle = p_int(dut.triangle.value)
        triangles.append(triangle)

    await RisingEdge(dut.clk)



def projector_runner():
    """Full Projector Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    # sim = os.getenv("SIM", "icarus")
    sim = os.getenv("SIM","vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "full_projector.sv", proj_path / "hdl" / "triangle_creator.sv", proj_path / "hdl" / "ddd_projector.sv", proj_path / "hdl" / "pipeline.sv", proj_path / "hdl" / "divider3.sv", proj_path / "hdl" / "log2.sv", proj_path / "hdl" / "sprite_creator.sv"]
    build_test_args = ["-Wall"]
    #values for parameters defined earlier in the code.
    # parameters = { 'KERNEL_DIMENSION': 3, 'K_SELECT': 2} # sharpen for now
 
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "full_projector"
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
    projector_runner()