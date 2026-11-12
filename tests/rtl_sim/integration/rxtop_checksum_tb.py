
import cocotb
import pandas as pd
from cocotb.triggers import Timer, with_timeout, RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame, AxiBus, AxiLiteMaster, AxiSlave, AxiLiteBus)
from byteUtils import swap_bytes32, swap_bytes16, getHex, adder_onec, print_hexes
from packet_builders import *
from parameter import *
from rxtop_fixture import RXTop




class probe:
    def __init__(self,rxtop):
        self.payloadFull  = []
        self.payloadH     = []
        self.payloadL     = []
        self.cs_payloadH  = []
        self.cs_payloadL  = []
        self.udp_final_cs = []
        cocotb.start_soon(self.mon_payload(rxtop))

    async def mon_payload(self, rxtop):
        udpcs_inst = rxtop.dut.cs_rx_udp.udpcs_core_inst
        plH_inst = udpcs_inst.onec_32B_H
        plL_inst = udpcs_inst.onec_32B_L
        while(True):
            if(udpcs_inst.cs_plH_vld.value):
                self.cs_payloadH.extend(getHex(udpcs_inst.cs_payloadH))
            if(udpcs_inst.cs_plL_vld.value):
                self.cs_payloadL.extend(getHex(udpcs_inst.cs_payloadL))
            if(plL_inst.str_vld.value):
                self.payloadL.extend(getHex(plL_inst.str_in))
            if(plH_inst.str_vld.value):
                self.payloadH.extend(getHex(plH_inst.str_in))
            if(udpcs_inst.pipe_axis_tvalid.value):
                self.payloadFull.extend(getHex(udpcs_inst.axis_filtered))
            if(udpcs_inst.checksum_valid.value):
                self.udp_final_cs.extend(getHex(udpcs_inst.checksum))
            await RisingEdge(rxtop.clks[0])

async def setup_rxtop_cs(dut, iface="eth_qsfp1"):
    rxtop = RXTop(dut)
    await rxtop.initialize(iface=iface)
    return rxtop, probe(rxtop)

def load_ila_data(wave_path, row_slice):
    header_column = "design_1_i/ila1/inst/net_slot_3_axis_tdata[63:0]"
    df = pd.read_csv(f"{wave_path}")[row_slice[0]:row_slice[1]].get(header_column).to_list()
    udp_msg = b''.join([bytes.fromhex(pkt)[::-1] for pkt in df])
    return udp_msg


@cocotb.test()
async def cs_test0(dut):
    """Read from a captured udp in ila (but the related udp)"""
    wave_path = f"{PROJ_DIR}/data/sharedtest/iladata.csv"

    rxtop, cs_probe = await setup_rxtop_cs(dut, iface="eth_qsfp1")
    udp_msg = load_ila_data(wave_path, [514,540])
    send_frame = await rxtop.tx_axis(udp_msg)
    await Timer(100, units="ns")
    # Read the axi4 lite to determine the valid
    ip4cs_val   = await rxtop.axil_rd(0x208)
    ip4cs_npass = await rxtop.axil_rd(0x20C)
    # exepected to see no fail ip4 checksum
    assert  int.from_bytes(ip4cs_val) == 0xffff, \
        f"Failed Checksum val: expected = 0xffff, actual={ip4cs_val}"
    assert int.from_bytes(ip4cs_npass) == 1, \
        f"Failed Checksum nFail: expected = 1, actual={ip4cs_npass}"

@cocotb.test()
async def cs_test1(dut):
    """Send two continous dataset"""
    wave_path = f"{PROJ_DIR}/data/sharedtest/iladata.csv"
    rxtop, cs_probe = await setup_rxtop_cs(dut, iface="eth_qsfp1")
    udp_msg = load_ila_data(wave_path, [514,540])
    nPacket = 2
    for i in range(nPacket):
        send_frame = await rxtop.tx_axis(udp_msg)
    await Timer(500, units="ns")
    # Read the axi4 lite to determine the valid
    ip4cs_val   = await rxtop.axil_rd(0x208)
    ip4cs_nPass = await rxtop.axil_rd(0x20C)
    udpcs_val   = await rxtop.axil_rd(0x210)
    udpcs_nPass = await rxtop.axil_rd(0x214)
    # exepected to see no fail ip4 and udp checksum
    # number of packet is 2
    assert int.from_bytes(ip4cs_val)==0xFFFF, \
        f"Failed IP4 check sum value: expected=0xFFFF, actual={ip4cs_val}"
    assert int.from_bytes(ip4cs_nPass)==nPacket, \
        f"Failed Checksum nFail: expected={nPacket}, actual={ip4cs_nPass}"
    assert int.from_bytes(udpcs_val)==0, \
        f"Failed UDP check sum value: expected=0, actual={udpcs_val}"
    assert int.from_bytes(udpcs_nPass)==nPacket, \
        f"Failed UDP Checksum nFail: expected={nPacket}, actual={udpcs_nPass}"

@cocotb.test()
async def cs_test2(dut):
    """Send two seperate datasets with a timegap"""
    wave_path = f"{PROJ_DIR}/data/sharedtest/iladata.csv"
    rxtop, cs_probe = await setup_rxtop_cs(dut, iface="eth_qsfp1")
    udp_msg = load_ila_data(wave_path, [514,540])
    nPacket = 2
    for i in range(nPacket):
        send_frame = await rxtop.tx_axis(udp_msg)
        await Timer(100, units="ns")
    await Timer(100, units="ns")
    # Read the axi4 lite to determine the valid
    ip4cs_val   = await rxtop.axil_rd(0x208)
    ip4cs_nPass = await rxtop.axil_rd(0x20C)
    udpcs_nPass = await rxtop.axil_rd(0x214)
    udpcs_val   = await rxtop.axil_rd(0x210)
    # exepected to see no fail ip4 and udp checksum
    # number of packet is 2
    assert int.from_bytes(ip4cs_val)==0xFFFF, \
        f"Failed IP4 check sum value: expected=0xFFFF, actual={ip4cs_val}"
    assert int.from_bytes(ip4cs_nPass)==nPacket, \
        f"Failed Checksum nFail: expected={nPacket}, actual={ip4cs_nPass}"
    assert int.from_bytes(udpcs_val)==0, \
        f"Failed UDP check sum value: expected=0, actual={udpcs_val}"
    assert int.from_bytes(udpcs_nPass)==nPacket, \
        f"Failed UDP Checksum nFail: expected={nPacket}, actual={udpcs_nPass}"
        
@cocotb.test()
async def cs_test3(dut):
    """Read from a captured udp in ila (but the related udp)"""
    wave_path = f"{PROJ_DIR}/data/sharedtest/iladata.csv"
    rxtop, cs_probe = await setup_rxtop_cs(dut, iface="eth_qsfp1")
    udp_msg = load_ila_data(wave_path, [514,540])
    send_frame = await rxtop.tx_axis(udp_msg)
    udpcs_inst = dut.cs_rx_udp.udpcs_core_inst
    await RisingEdge(udpcs_inst.cs_plH_vld)
    rx_msg = await with_timeout(rxtop.rx_axis(0), timeout_time=1, timeout_unit= "us")
    await Timer(400, units="ns")
    assert (len(cs_probe.udp_final_cs)) >= 1, f"The test list is empty"
    for cs in cs_probe.udp_final_cs:
        assert int.from_bytes(cs) == 0, f"Expected=0, Actual={cs} "
    # This little temp test is to comfirm the output is matching with the input
    # However, in the future, I should map csgate stream out directly here 
    # for proper test, as m00 will be used for something else
    msg = b''.join(b for b in rx_msg)
    tx_len = len(udp_msg)
    assert msg[:tx_len] == udp_msg, f"Expected={udp_msg}, Act={msg}"


@cocotb.test()
async def cs_test4(dut):
    """Read from a captured udp in ila"""
    wave_path = f"{PROJ_DIR}/data/sharedtest/iladata.csv"
    rxtop = RXTop(dut)
    await rxtop.initialize(iface="eth_qsfp1")
    udp_msg = load_ila_data(wave_path, [514,543])
    send_frame = await rxtop.tx_axis(udp_msg)
    await Timer(1000, unit="ns")
    # **** Evaluation ****
    assert rxtop.dut.udp_vld_cnt.value == 1, \
        f"UDP: Expected={rxtop.dut.udp_vld_cnt.value} to receive only 1 udp pkt"
    assert rxtop.dut.arp_vld_cnt.value == 0, \
        f"ARP: Expected={rxtop.dut.arp_vld_cnt.value} to receive 0  pkt"
    pass
