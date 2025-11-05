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

@cocotb.test()
async def test_a(dut):
    """cocotb test"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units="ns").start())

    dut._log.info("Holding reset...")
    dut.rst.value = 1

    dut.active.value = 0
    dut.triangle.value = 0
    dut.triangle_valid.value = 0

    await ClockCycles(dut.clk, 3)

    dut.rst.value = 0

    await ClockCycles(dut.clk, 3)

    dut.triangle_valid.value = 1
    dut.triangle.value = convert_to_triangle(0xFF00, 0, 0, 0, 100, 100, 100, 10)

    await ClockCycles(dut.clk, 1)

    dut.triangle_valid.value = 1
    dut.triangle.value = convert_to_triangle(0xFFFF, 50, 0, 150, 50, 200, 200, 10)

    await ClockCycles(dut.clk, 1)

    dut.triangle_valid.value = 1
    dut.triangle.value = convert_to_triangle(0x000F, 160, 0, 320, 180, 0, 180, 50)

    await ClockCycles(dut.clk, 1)

    dut.triangle_valid.value = 0

    await ClockCycles(dut.clk, 10)

    dut.active.value = 1

    for _ in range(30000):
        await read_clock_cycle(dut)

    with open("test_renderer_list.txt", "w") as file:
        file.write(str(frame_buffer))

def p_int(str):
    if str == 'X':
        return 0
    else:
        try:
            return int(str)
        except:
            return 0

frame_buffer = [ [0] * 320 for _ in range(180) ]

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



def renderer_runner():
    """Renderer Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    # sim = os.getenv("SIM", "icarus")
    sim = os.getenv("SIM","vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "renderer.sv", proj_path / "hdl" / "pixel_calculator.sv", proj_path / "hdl" / "tile_painter.sv", proj_path / "hdl" / "pipeline.sv", proj_path / "hdl" / "renderer.sv", proj_path / "hdl" / "xilinx_true_dual_port_read_first_2_clock_ram.v"]
    build_test_args = ["-Wall"]
    #values for parameters defined earlier in the code.
    # parameters = { 'KERNEL_DIMENSION': 3, 'K_SELECT': 2} # sharpen for now
 
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "renderer"
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
    renderer_runner()