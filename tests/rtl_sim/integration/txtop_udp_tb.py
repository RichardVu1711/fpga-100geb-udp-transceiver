import cocotb
import pandas as pd
import numpy as np
from cocotb.triggers import Timer, with_timeout, RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame, AxiBus, AxiLiteMaster, AxiSlave, AxiLiteBus)
from byteUtils import swap_bytes32, swap_bytes16, getHex, adder_onec, print_hexes
from packet_builders import *
from parameter import *
from rxtop_fixture import TXTop
from marketdata import stream_info, market_info


async def initialize_components(dut, csv_path):
    txtop = TXTop(dut)
    await txtop.initialize(iface="eth_qsfp1")
    # read from a csv file and send them directly to hardware
    market_book = stream_info(csv_path)
    return txtop, market_book

def addtimeOut(func):
    return with_timeout(func, timeout_time=1, timeout_unit= "us")


class probe:
    def __init__(self,txtop):
        self.clk          = txtop.dut.axil_aclk
        self.crt_tx_udp   = txtop.dut.crt_tx_udp
        self.ip4cs_core   = txtop.dut.crt_tx_udp.ip4cs_core_inst
        self.udpcs_core   = txtop.dut.crt_tx_udp.udpcs_core_inst
        self.ip4hdr       = []
        self.udphdr       = []
        self.psdhdr       = []
        self.payload      = []
        self.ip4cs_cap    = []
        self.udpcs_cap    = []
        self.cs_plH       = []
        self.cs_plL       = []
        self.psdhdr_cscap = []
        self.udphdr_cscap = []
        self.final_udp    = []  # udp cs captured  at crt_tx_udp module
        self.final_ip4    = []  # ip4 cs captured  at crt_tx_udp module

        cocotb.start_soon(self.mon_payload())
    
    async def mon_payload(self):
        while(True):
            if(self.ip4cs_core.ip4_hdr_vld.value):
                self.ip4hdr.extend(getHex(self.ip4cs_core.ip4_hdr))
            if(self.ip4cs_core.ip4cs_vld.value):
                self.ip4cs_cap.extend(getHex(self.ip4cs_core.ip4cs))
            if(self.udpcs_core.pipe_axis_tvalid.value):
                self.payload.extend(getHex(self.udpcs_core.axis_filtered))
            if(self.udpcs_core.udp_hdr_vld.value):
                self.udphdr.extend(getHex(self.udpcs_core.udp_header))
                self.psdhdr.extend(getHex(self.udpcs_core.pseudo_header))
            if(self.udpcs_core.cs_plH_vld.value): # once the payload valid is high, both low and high are captured
                self.cs_plH.extend(getHex(self.udpcs_core.cs_payloadH))
                self.cs_plL.extend(getHex(self.udpcs_core.cs_payloadL))
            if(self.udpcs_core.csu_hdr_vld.value): # once the header valid is high, both udp and psd are captured
                self.psdhdr_cscap.extend(getHex(self.udpcs_core.csp_header))
                self.udphdr_cscap.extend(getHex(self.udpcs_core.csu_header))
            if(self.udpcs_core.checksum_valid.value): # once the header valid is high, both udp and psd are captured
                self.udpcs_cap.extend(getHex(self.udpcs_core.checksum))
            if(self.crt_tx_udp.hdr_vld.value):
                cal_hdr = int(self.crt_tx_udp.calhdr_info)
                self.final_udp.append(cal_hdr & 0xFFFF)
                self.final_ip4.append((cal_hdr >> 32) & 0xFFFF)
            await RisingEdge(self.clk)

@cocotb.test()
async def udp_test0(dut):
    """ Send and expect to get something in the m00"""
    data_file = f"{PROJ_DIR}/data/sharedtest/AAPL_aggs_2026-01-01_2026-03-01.csv"
    nRowPerPkt = 2;
    txtop, market_book = await initialize_components(dut, data_file)
    extr_data, msg = market_book.to_axis_f(0, nRowPerPkt)
    market_book.print_infos()
    await txtop.tx_axis(msg)
    await Timer(1000, unit="ns")
    recv_data = await addtimeOut(txtop.rx_axis())
    print(f"Capture {len(recv_data[0])} bytes from AXI Stream Interface")
    assert len(recv_data[0]) != 0, f"Capture Empty array, {len(recv_data[0])}"
    pass
    
@cocotb.test()
async def cs_test0(dut):
    """ Send a packet and validate the checksum in TX side"""
    data_file   = f"{PROJ_DIR}/data/sharedtest/AAPL_aggs_2026-01-01_2026-03-01.csv"
    nRowPerPkt  = 4; # The minimum number that needs this
    nPkt        = 1;
    nBytePerPkt = 64;

    txtop, market_book = await initialize_components(dut, data_file)
    sig_probed = probe(txtop=txtop)
    ip4_len = int(0x20+nRowPerPkt*64).to_bytes(4,'little')
    udp_len = int(0x08+nRowPerPkt*64).to_bytes(4,'little')
    # re-configure on the number of IP len + UDP len
    await txtop.axictl.write(TX_REG_MAP["ip4_length"],   ip4_len) # IP header (20) + Payload (2*64 Bytes)
    await txtop.axictl.write(TX_REG_MAP["udp_checksum"], udp_len) # UDP header(20) + Payload (2*64 Bytes)

    # get data in byte msg
    for i in range(nPkt):
        extr_data, msg = market_book.to_axis_f(0, nRowPerPkt)
        await txtop.tx_axis(msg)
    await Timer(2000, unit="ns")
    # I neeed to calculate the IP checksum manually. given the configuration
    # The most direct approach is to take the data directly from the the hardware when capturing
    print("Capture signals are: ")
    for i in range(nPkt):
        sIdx = (i)*nBytePerPkt
        payloadH, payloadL = [], []
        for b in range(sIdx, sIdx + nBytePerPkt):
            beat = sig_probed.payload[b*32:(b+1)*32]
            payloadH.extend(beat[0:16])    # bits 511:256 of that beat
            payloadL.extend(beat[16:32])   # bits 255:0 of that beat
        udphdr   = sig_probed.udphdr[i*4:(i+1)*4]
        psdhdr   = sig_probed.psdhdr[i*6:(i+1)*6]
        hdr_idx  = [(i)*20, (i+1)*20] # each ip4 header has 20 bytes
        assert sig_probed.ip4cs_cap[i] == adder_onec(sig_probed.ip4hdr[hdr_idx[0]:hdr_idx[1]]), \
            f"ip4 checksum failed: SW={adder_onec(sig_probed.ip4hdr[hdr_idx[0]:hdr_idx[1]])} HW={sig_probed.ip4cs_cap[i]}"
        print_hexes("plH=",payloadH)
        print_hexes("plL=",payloadL)
        print_hexes("udp_hdr=",udphdr)
        print_hexes("psd_hdr=",psdhdr)
        payload_adder = payloadH + payloadL +  udphdr + psdhdr
        sw_sum = int.from_bytes(adder_onec(payload_adder), byteorder='big')
        sw_checksum = (~sw_sum) & 0xFFFF          # one's-complement, masked to 16 bits
        assert sig_probed.psdhdr_cscap[i] == adder_onec(psdhdr),\
            f"pseudo header expected={adder_onec(psdhdr)}, act={sig_probed.psdhdr_cscap[i]}"
        assert sig_probed.udphdr_cscap[i] == adder_onec(udphdr),\
            f"pseudo header expected={adder_onec(udphdr)}, act={sig_probed.udphdr_cscap[i]}"
        assert int.from_bytes(sig_probed.udpcs_cap[i], 'big') == sw_checksum, \
            f"udp checksum failed: SW={sw_checksum:04x} HW={sig_probed.udpcs_cap[i].hex()}"
        assert sig_probed.final_udp[i] == sw_checksum, \
            f"checksum at crt_tx_udp failed. SW={sw_checksum} HW={sig_probed.final_udp[i]}"