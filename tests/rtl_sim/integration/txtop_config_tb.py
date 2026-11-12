import cocotb
import pandas as pd
from cocotb.triggers import Timer, with_timeout, RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame, AxiBus, AxiLiteMaster, AxiSlave, AxiLiteBus)
from byteUtils import swap_bytes32, swap_bytes16, getHex, adder_onec, print_hexes
from packet_builders import *
from parameter import *
from rxtop_fixture import TXTop

@cocotb.test()
async def init_test(dut):
    txtop = TXTop(dut)
    await txtop.initialize(iface="eth_qsfp1")
    pass

