from pynq import Overlay
from pynq import MMIO
from parameters import *

REG_MAP = {
    # Configuration registers
    "DBG_TXMODE":            0x0000,
    "NIC_MAC_15_00":         0x0004,
    "NIC_MAC_31_16":         0x0008,
    "NIC_MAC_47_32":         0x000C,
    "CMAC_MAC_15_00":        0x0010,
    "CMAC_MAC_31_16":        0x0014,
    "CMAC_MAC_47_32":        0x0018,
    "MAC_TYPE":              0x001C,
    "IP_VERSION":            0x0020,
    "DSCP_ECN":              0x0024,
    "IP4_LENGTH":            0x0028,
    "IP4_IDENTITY":          0x002C,
    "IP4_FLAG_FRAG":         0x0030,
    "IP4_TIME_PROTO":        0x0034,
    "IP4_CHECKSUM":          0x0038,
    "CMAC_IP":               0x003C,
    "NIC_IP":                0x0040,
    "CMAC_PORT":             0x0044,
    "NIC_PORT":              0x0048,
    "UDP_LENGTH":            0x004C,
    "UDP_CHECKSUM":          0x0050,
}

class txtop:
    def __init__(self,ol):
        print("==== Configure TXTOP ====")
        self.txtop        = ol.TXTop_inst # This will be changed in the next bitstream
        self.register_map = REG_MAP
        self.cfgs         = IFACE_MODE["eth_qsfp1"]
        self.cfg_iface()        


    def cfg_iface(self):
        cmac_mac  = self.cfgs['cmac']['mac']
        nic_mac   = self.cfgs['nic']['mac']
        cmac_ip   = self.cfgs['cmac']['ip']
        nic_ip    = self.cfgs['nic']['ip']
        cmac_port = self.cfgs['cmac']['port']
        nic_port  = self.cfgs['nic']['port']

        write_cfgs = {
            "DBG_TXMODE":     0x00F1,  # let the arp pass first => move to the 0x0000 for normal operation
            "CMAC_MAC_15_00": swap_bytes16(cmac_mac >> 32) & 0xFFFF,  #[4] and [5]
            "CMAC_MAC_31_16": swap_bytes16(cmac_mac >> 16) & 0xFFFF, # [2] and [3]
            "CMAC_MAC_47_32": swap_bytes16(cmac_mac >> 0) & 0xFFFF, # [0] and [1]
            "NIC_MAC_15_00":  swap_bytes16(nic_mac >> 32) & 0xFFFF,
            "NIC_MAC_31_16":  swap_bytes16(nic_mac >> 16) & 0xFFFF,
            "NIC_MAC_47_32":  swap_bytes16(nic_mac >> 0) & 0xFFFF,
            "MAC_TYPE":       0x0800,  # IPv4
            "IP_VERSION":     0x45,    # IPv4 + IHL=5
            "DSCP_ECN":       0x0000,
            "IP4_LENGTH":     0x0128, # 4 * 64 Bytes of payload + 42 Bytes of header = 296B
            "IP4_IDENTITY":   0x0000,
            "IP4_FLAG_FRAG":  0x0000,
            "IP4_TIME_PROTO": 0x0011,
            "IP4_CHECKSUM":   0x0000, # will be replaced
            "CMAC_IP":        swap_bytes32(cmac_ip),
            "NIC_IP":         swap_bytes32(nic_ip),
            "CMAC_PORT":      cmac_port,
            "NIC_PORT":       nic_port,
            "UDP_LENGTH":     0x0114, # 4*64  + 20 Bytes of headers = 276 B
            "UDP_CHECKSUM":   0x0000
        }
        for name, val in write_cfgs.items():
            self.txtop.write(self.register_map[name], val.to_bytes(4, byteorder='little'))

    def write_axil(self, str_name, val):
        self.txtop.write(self.register_map[f"{str_name}"],val)

    def read_axil(self, str_name):
        stt = self.txtop.read(self.register_map[f"{str_name}"])
        print(f"{str_name}={stt}")
        return stt
    
    def status_update(self):
        print("Confirm Status Regs")
        for name, val in self.register_map.items():
            if not name.startswith("CUSTOM_ARP_REG"):
                stt = self.txtop.read(self.register_map[f"{name}"])
                print(f"{name}: {hex(stt)}")