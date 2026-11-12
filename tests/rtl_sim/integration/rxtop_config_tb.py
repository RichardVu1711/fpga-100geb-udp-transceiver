
import cocotb
import pandas as pd
from cocotb.triggers import Timer, with_timeout, RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame, AxiBus, AxiLiteMaster, AxiSlave, AxiLiteBus)
from byteUtils import swap_bytes32, swap_bytes16, getHex, adder_onec, print_hexes
from packet_builders import *
from parameter import *
from rxtop_fixture import RXTop
from rxtop_checksum_tb import load_ila_data

def assert_val(actual, expected, msg=None):
    assert actual == expected, f"{msg}: expected = {expected}, actual={actual}"

@cocotb.test()
async def init_test(dut):
    rxtop = RXTop(dut)
    await rxtop.initialize(iface="eth_qsfp1")
    pass

@cocotb.test()
async def init_test0(dut):
    """ Measure the gap betwewen 2 packets with gap_between_pkts register"""
    rxtop = RXTop(dut)
    await rxtop.initialize(iface="eth_qsfp1")
    wave_path = f"{PROJ_DIR}/data/sharedtest/iladata.csv"
    udp_msg = load_ila_data(wave_path, [514,540])
    clk_period = 10
    nwait      = 10
    
    # Read the initial value of the counter
    gap_cnt = await rxtop.axil_rd_int(0x220)
    assert_val(gap_cnt, 0)
    ## Send message, wait X ns, send another => Xns = gap

    send_frame = await rxtop.tx_axis(udp_msg)
    await rxtop.axis_src[0].wait()
    await Timer(clk_period*nwait, unit="ns")
    send_frame = await rxtop.tx_axis(udp_msg)
    await Timer(100, unit="ns")

    ## validate the gap
    gap_cnt = await rxtop.axil_rd_int(0x220)
    assert_val(gap_cnt-1, nwait, "Gap After 2 Transmission")

