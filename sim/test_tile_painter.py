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
    dut.active.value = 0
    dut.wipe.value = 0

    for i in range(2):
        await cycle(dut)

    dut._log.info("Running....")

    dut.active.value = 1
    dut.rst.value = 0

    for _ in range(10000):
        await cycle(dut)
    
    print(TILE)
    
    dut._log.info("Wiping.....")

    dut.wipe.value = 1
    
    for _ in range(10000):
        await cycle(dut)

    print(TILE)


def convert_to_triangle(color, p1x, p1y, p2x, p2y, p3x, p3y, total_depth):
    return color * (2**112) + p1x * (2**96) + p1y * (2**80) + p2x * (2**64) + p2y * (2**48) + p3x * (2**32) + p3y * (2**16) + total_depth

BRAM = [
    convert_to_triangle(0xFF00, 15, 15, 20, 0, 10, 10, 50),
    # convert_to_triangle(63, 0, 0, 0, 10, 10, 10, 100),
]

NUM_TRIANGLES = len(BRAM)
X_OFFSET = 0
Y_OFFSET = 0

TILE = [0xFFFF] * (20*45)

bram_read_on_deck = 0
tile_read_on_deck = 0

def possible_int(str):
    if str == 'X':
        return 0
    else:
        try:
            return int(str)
        except:
            return 0

async def cycle(dut):
    global tile_read_on_deck, bram_read_on_deck, BRAM, TILE, NUM_TRIANGLES, X_OFFSET, Y_OFFSET

    await FallingEdge(dut.clk)

    triangle_bram_index = possible_int(dut.bram_triangle_read_addr.value)
    tile_bram_index = possible_int(dut.tile_bram_read_addr.value)

    write_addy = possible_int(dut.tile_bram_write_addr.value)
    write_valid = possible_int(dut.tile_bram_write_valid.value)
    write_data = possible_int(dut.tile_bram_write_data.value)

    if (write_valid == 1):
        TILE[write_addy] = write_data
    
    await RisingEdge(dut.clk)

    dut.tile_bram_read_data.value = tile_read_on_deck
    tile_read_on_deck = TILE[tile_bram_index]

    dut.bram_triangle_read_data.value = bram_read_on_deck
    bram_read_on_deck = BRAM[triangle_bram_index]

    dut.num_triangles.value = NUM_TRIANGLES
    dut.x_offset.value = X_OFFSET
    dut.y_offset.value = Y_OFFSET

def tile_painter_runner():
    """Tile Painter Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    # sim = os.getenv("SIM", "icarus")
    sim = os.getenv("SIM","vivado")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "pixel_calculator.sv", proj_path / "hdl" / "tile_painter.sv", proj_path / "hdl" / "pipeline.sv"]
    build_test_args = ["-Wall"]
    #values for parameters defined earlier in the code.
    # parameters = { 'KERNEL_DIMENSION': 3, 'K_SELECT': 2} # sharpen for now
 
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "tile_painter"
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
    tile_painter_runner()