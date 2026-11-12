
import cocotb
from cocotb.triggers import Timer, with_timeout, RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame, AxiBus, AxiLiteMaster, AxiSlave, AxiLiteBus)
from byteUtils import swap_bytes32, swap_bytes16, getHex, adder_onec, print_hexes
from packet_builders import *
from parameter import *
from rxtop_fixture import RXTop

async def send_arp_pkt(str_raw, xcvc):
    msg = bytes.fromhex(str_raw)
    print(f'msg = {msg.hex()}')
    await xcvc.tx_axis(msg)
    rev_pkt = await with_timeout( xcvc.rx_axis(sig_idx=1), timeout_time=1, timeout_unit= "us")
    return rev_pkt

@cocotb.test()
async def arp_test0(dut):
    """ Send the correct ARP package """    
    """ Expect to receive the proper response """
    rxtop = RXTop(dut)
    arp_msg = generate_test_arp()
    await rxtop.initialize(iface="eth_qsfp1")
    cocotb.start_soon(rxtop.stream_monitor(rxtop.dut.s00_axis_tdata))
    recv = await send_arp_pkt(arp_msg, rxtop)
    captured_msg = bytes(recv[0]).hex()
    l_msg = len(captured_msg);
    await Timer(100, unit="ns")
    assert captured_msg[0:12] == "649d99ffebeb",\
        "FAILED: unmatched MAC NIC in ARP reply"
    assert captured_msg[12:24] == "112233445566",\
        "FAILED: unmatched MAC CMAC in ARP reply"
    assert captured_msg[24:28] == "0806",\
        "FAILED: unmatched MAC Type (0x0806) in ARP reply"
    assert captured_msg[40:44] == "0002",\
        "FAILED: unmatched ARP OP (0x0002) in ARP reply"
    # assert captured_msg[]
    arp_msg = from_corrupt_arp()
    recv = await send_arp_pkt(arp_msg, rxtop)
    await Timer(1000, unit="ns")

@cocotb.test()
async def arp_test1(dut):
    """ Send the ARP request that captured from ILA """    
    """ Expect to receive the proper response """
    rxtop = RXTop(dut)
    arp_msg = from_captured_arp()
    await rxtop.initialize(iface="eth_qsfp1")
    cocotb.start_soon(rxtop.stream_monitor(dut.s00_axis_tdata))
    recv = await send_arp_pkt(arp_msg, rxtop)
    captured_msg = bytes(recv[0]).hex()
    l_msg = len(captured_msg);
    assert captured_msg[0:12] == "649d99ffebeb",\
            "FAILED: unmatched MAC NIC in ARP reply"
    assert captured_msg[12:24] == "112233445566",\
            "FAILED: unmatched MAC CMAC in ARP reply"
    assert captured_msg[24:28] == "0806",\
        "FAILED: unmatched MAC Type (0x0806) in ARP reply"
    assert captured_msg[40:44] == "0002",\
        "FAILED: unmatched ARP OP (0x0002) in ARP reply"

