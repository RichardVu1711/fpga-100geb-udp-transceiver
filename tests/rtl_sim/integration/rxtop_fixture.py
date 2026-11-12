import cocotb
import logging
import pandas as pd
import struct
from cocotb.triggers import Timer, with_timeout, RisingEdge
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame, AxiBus, AxiLiteMaster, AxiSlave, AxiLiteBus)
import os
from unit.tbObj import uutObj
from byteUtils import swap_bytes32, swap_bytes16, getHex, adder_onec, print_hexes
from packet_builders import from_captured_arp, from_corrupt_arp, generate_test_arp
from parameter import *


class RXTop(uutObj):   
    def __init__(self, dut):
            sigs = ["s00_axis", "m00_axis", "marp_axis"]
            super().__init__(dut, sigs)
            #set up axil interface
            self.axictl = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), 
                                       dut.axil_aclk,dut.axil_aresetn,
                                       reset_active_level=False) # activate high
            pass
    async def axil_rd(self, addr):
        rd_reg = await self.axictl.read(addr, 4)
        rd_val = rd_reg.data[::-1]
        return rd_val

    async def axil_rd_int(self, addr):
        rd_reg = await self.axictl.read(addr, 4)
        rd_val = rd_reg.data[::-1]
        return int.from_bytes(rd_val)
    
    async def axil_cfg(self, iface="lo"):
        nic_mac = iface_mode[iface]['nic']['mac']
        cmac_mac = iface_mode[iface]['cmac']['mac']
        cmac_ip = iface_mode[iface]['cmac']['ip']
        nic_ip = iface_mode[iface]['nic']['ip']
        # in axi transfer, the data is sent in little-endian format:
        write_cfgs = {
            "eth_cmac_mac_2": swap_bytes16(cmac_mac >> 0) & 0xFFFF,  #[4] and [5]
            "eth_cmac_mac_1": swap_bytes16(cmac_mac >> 16) & 0xFFFF, # [2] and [3]
            "eth_cmac_mac_0": swap_bytes16(cmac_mac >> 32) & 0xFFFF, # [0] and [1]
            "eth_nic_mac_2": swap_bytes16(nic_mac >> 0) & 0xFFFF,
            "eth_nic_mac_1": swap_bytes16(nic_mac >> 16) & 0xFFFF,
            "eth_nic_mac_0": swap_bytes16(nic_mac >> 32) & 0xFFFF,
            "eth_mac_type": 0x0800,  # IPv4
            "ip4_version": 0x45,  # IPv4 + IHL=5
            "ip4_length": 0,  # will be set by the RXTop module
            "ip4_checksum": 0,  # will be set by the RXTop module
            "ip4_cmac_ip": swap_bytes32(cmac_ip),
            "ip4_nic_ip": swap_bytes32(nic_ip),
            "udp_cmac_port": iface_mode[iface]['cmac']['port'],
            "udp_nic_port": iface_mode[iface]['nic']['port'],
        }
        for name, val in write_cfgs.items():
            await self.axictl.write(AXI_REG_MAP[name], val.to_bytes(4, byteorder='little'))

    async def initialize(self, iface="lo"):
        cocotb.start_soon(self.clk_gen())
        self.no_backpressure()
        await self.gen_resetn()
        await Timer(100, unit="ns")
        await self.axil_cfg(iface)
        pass

class TXTop(uutObj):
    def __init__(self, dut):
        sigs = ["sarp_axis", "s00_axis", "m00_axis"]
        super().__init__(dut, sigs)
        #set up axil interface
        self.axictl = AxiLiteMaster(AxiLiteBus.from_prefix(dut, "s_axil"), 
                                    dut.axil_aclk,dut.axil_aresetn,
                                    reset_active_level=False) # activate high
        pass
    async def axil_cfg(self, iface="lo"):
        nic_mac = iface_mode[iface]['nic']['mac']
        cmac_mac = iface_mode[iface]['cmac']['mac']
        cmac_ip = iface_mode[iface]['cmac']['ip']
        nic_ip = iface_mode[iface]['nic']['ip']
        # in axi transfer, the data is sent in little-endian format:
        write_cfgs = {
            "nic_mac_2"     : swap_bytes16(nic_mac >> 0) & 0xFFFF,   #[4] and [5]
            "nic_mac_1"     : swap_bytes16(nic_mac >> 16) & 0xFFFF,  #[2] and [3]
            "nic_mac_0"     : swap_bytes16(nic_mac >> 32) & 0xFFFF,  #[0] and [1]
            "cmac_mac_2"    : swap_bytes16(cmac_mac >> 0) & 0xFFFF,  #[4] and [5]
            "cmac_mac_1"    : swap_bytes16(cmac_mac >> 16) & 0xFFFF, #[2] and [3]
            "cmac_mac_0"    : swap_bytes16(cmac_mac >> 32) & 0xFFFF, #[0] and [1]
            "mac_type"      : 0x0800,  # IPv4
            "ip4_version"   : 0x45,  # IPv4 + IHL=5
            "ip4_dscp_ecn"  : 0, # 1 Byte of unknown
            "ip4_length"    : 0, # will be set by TXTop module
            "ip4_identity"  : 0, # will be set by the TXTop module
            "ip4_flag_frag" : 0, # will be set by the TXTop module
            "ip4_protocol"  : swap_bytes16(0x4011),  # TTL=0x40 UDP=0x11
            "ip4_checksum"  : 0,  # will be set by the TXTop module
            "ip4_cmac_ip"   : swap_bytes32(cmac_ip), # cmac_ip
            "ip4_nic_ip"    : swap_bytes32(nic_ip),  # nic_ip
            "udp_cmac_port" : iface_mode[iface]['cmac']['port'], # cmac_port
            "udp_nic_port"  : iface_mode[iface]['nic']['port'],  # nic_port
            "udp_length"    : 0,  # will be set by the TXTop module
            "udp_checksum"  : 0,  # will be set by the TXTop module
        }
        for name, val in write_cfgs.items():
            print(f"Write {val.to_bytes(4, byteorder='little')} at {TX_REG_MAP[name]}")
            await self.axictl.write(TX_REG_MAP[name], val.to_bytes(4, byteorder='little'))

    async def initialize(self, iface="lo"):
        cocotb.start_soon(self.clk_gen())
        self.no_backpressure()
        await self.gen_resetn()
        await Timer(100, unit="ns")
        await self.axil_cfg(iface)
        pass