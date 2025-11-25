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
from cocotb.runner import get_runner
# from vicoco.vivado_runner import get_runner
test_file = os.path.basename(__file__).replace(".py","")

CLK_PERIOD = 10
PCLK_PERIOD = 20

@cocotb.test()
async def test_a(dut):
    """cocotb test"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units="ns").start())

    dut._log.info("Holding reset...")
    dut.rst.value = 1
    dut.activate.value = 0

    await ClockCycles(dut.clk, 3)

    dut.rst.value = 0

    await ClockCycles(dut.clk, 3)

    for _ in range(100):
        dut.activate.value = 1

        await ClockCycles(dut.clk, 1)

        dut.activate.value = 0

        await ClockCycles(dut.clk, 200)


def obstacle_generator_runner():
    """Obstacle Generator Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    # sim = os.getenv("SIM","vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "obstacle_generator.sv"]
    build_test_args = ["-Wall"]
    #values for parameters defined earlier in the code.
    # parameters = { 'KERNEL_DIMENSION': 3, 'K_SELECT': 2} # sharpen for now
 
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "obstacle_generator"
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
    obstacle_generator_runner()