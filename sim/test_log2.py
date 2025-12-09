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

random.seed(0)

CLK_PERIOD = 10
PCLK_PERIOD = 20

def convert_to_triangle(color, p1x, p1y, p2x, p2y, p3x, p3y, total_depth):
    return color * (2**112) + p1x * (2**96) + p1y * (2**80) + p2x * (2**64) + p2y * (2**48) + p3x * (2**32) + p3y * (2**16) + total_depth

@cocotb.test()
async def test_a(dut):
    """cocotb test"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units="ns").start())

    await ClockCycles(dut.clk, 5)

    dut.c = 625
    await ClockCycles(dut.clk, 1)

    for i in range(100):
        dut.c = random.randint(0, 2**20-1)
        await ClockCycles(dut.clk, 1)



def p_int(str):
    if str == 'X':
        return 0
    else:
        try:
            return int(str)
        except:
            return 0

frame_buffer = [ [0] * 1280 for _ in range(180) ]

async def read_clock_cycle(dut):

    await FallingEdge(dut.clk)

    if p_int(dut.valid.value) == 1:
        h = p_int(dut.h_count.value)
        v = p_int(dut.v_count.value)
        data = p_int(dut.data.value)

        try:
            frame_buffer[v][h] = data

        except:
            print(h,v)
            raise Exception("lolz")

    await RisingEdge(dut.clk)



def small_multiplier():
    """small_multiplier Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    # sim = os.getenv("SIM", "icarus")
    sim = os.getenv("SIM","vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "log2.sv"]
    build_test_args = ["-Wall"]
    #values for parameters defined earlier in the code.
    # parameters = { 'KERNEL_DIMENSION': 3, 'K_SELECT': 2} # sharpen for now
 
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "log2"
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
    small_multiplier()