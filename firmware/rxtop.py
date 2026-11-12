from pynq import Overlay
from pynq import MMIO
from parameters import *
"""
AXI-Lite register map. Ported from p11's firmware/rxtop.hpp.
All registers are 32-bit and 4-byte aligned.
"""

REG_MAP = {
    # Configuration registers
    "DBG_RXMODE":            0x0000,
    "CMAC_MAC_15_00":        0x0004,
    "CMAC_MAC_31_16":        0x0008,
    "CMAC_MAC_47_32":        0x000C,
    "NIC_MAC_15_00":         0x0010,
    "NIC_MAC_31_16":         0x0014,
    "NIC_MAC_47_32":         0x0018,
    "MAC_TYPE":              0x001C,
    "IP_VERSION":            0x0020,
    "IP_PAYLOAD_LENGTH":     0x0024,
    "IP_CHECKSUM":           0x0028,
    "CMAC_IP":               0x002C,
    "NIC_IP":                0x0030,
    "CMAC_PORT":             0x0034,
    "NIC_PORT":              0x0038,
    "UDP_CHECKSUM":          0x003C,
    "UDP_LENGTH":            0x0040,

    # Custom ARP configuration registers
    "CUSTOM_ARP_REG_0":      0x0100,
    "CUSTOM_ARP_REG_1":      0x0104,
    "CUSTOM_ARP_REG_2":      0x0108,
    "CUSTOM_ARP_REG_3":      0x010C,
    "CUSTOM_ARP_REG_4":      0x0110,
    "CUSTOM_ARP_REG_5":      0x0114,
    "CUSTOM_ARP_REG_6":      0x0118,
    "CUSTOM_ARP_REG_7":      0x011C,
    "CUSTOM_ARP_REG_8":      0x0120,
    "CUSTOM_ARP_REG_9":      0x0124,
    "CUSTOM_ARP_REG_10":     0x0128,
    "CUSTOM_ARP_REG_11":     0x012C,
    "CUSTOM_ARP_REG_12":     0x0130,
    "CUSTOM_ARP_REG_13":     0x0134,
    "CUSTOM_ARP_REG_14":     0x0138,
    "CUSTOM_ARP_REG_15":     0x013C,
    "CUSTOM_ARP_REG_16":     0x0140,
    "CUSTOM_ARP_REG_17":     0x0144,
    "CUSTOM_ARP_REG_18":     0x0148,
    "CUSTOM_ARP_REG_19":     0x014C,
    "CUSTOM_ARP_REG_20":     0x0150,
    "CUSTOM_ARP_REG_21":     0x0154,
    "CUSTOM_ARP_REG_22":     0x0158,
    "CUSTOM_ARP_REG_23":     0x015C,
    "CUSTOM_ARP_REG_24":     0x0160,

    # Status registers
    "UDP_VALID_COUNT":       0x0200,
    "ARP_VALID_COUNT":       0x0204,
    "IP_CHECKSUM_LOGGER":    0x0208,
    "IP_CHECKSUM_NPASS":     0x020C,
    "UDP_CHECKSUM_LOGGER":   0x0210,
    "UDP_CHECKSUM_NPASS":    0x0214,
    "GATE_MM_GAP":           0x0218,
    "CS_FAILED_COUNT":       0x021C,
    "GAP_BETWEEN_PKT":       0x0220,

    # Captured header information
    "CAP_CMAC_MAC_15_00":    0x0304,
    "CAP_CMAC_MAC_31_16":    0x0308,
    "CAP_CMAC_MAC_47_32":    0x030C,
    "CAP_NIC_MAC_15_00":     0x0310,
    "CAP_NIC_MAC_31_16":     0x0314,
    "CAP_NIC_MAC_47_32":     0x0318,
    "CAP_MAC_TYPE":          0x031C,
    "CAP_IP_VERSION":        0x0320,
    "CAP_IP_PAYLOAD_LENGTH": 0x0324,
    "CAP_IP_CHECKSUM":       0x0328,
    "CAP_CMAC_IP":           0x032C,
    "CAP_NIC_IP":            0x0330,
    "CAP_CMAC_PORT":         0x0334,
    "CAP_NIC_PORT":          0x0338,
    "CAP_UDP_CHECKSUM":      0x033C,
    "CAP_UDP_LENGTH":        0x0340,

    # Logger Reader information
    "LOGGER_CLEAR":          0x400,
    "LOGGER_RADDR":          0x404,
    "LOGGER_RDOUT_S":        0x408,
    "LOGGER_RDOUT_E":        0x444,
}
# Software ARP reply, used for testing purposes only.
ARP_REPLY_WORDS = [
    0xFF999D64,  # offset 0x64 - dst MAC [0:3]: 64 9D 99 FF
    0x2211EBEB,  # offset 0x68 - dst MAC [4:5] + src MAC [0:1]: EB EB 11 22
    0x66554433,  # offset 0x6C - src MAC [2:5]: 33 44 55 66
    0x01000608,  # offset 0x70 - EtherType + HW type: 08 06 00 01
    0x04060008,  # offset 0x74 - Proto type + HW len + Proto len: 08 00 06 04
    0x22110200,  # offset 0x78 - Opcode + Sender MAC[0:1]: 00 02 11 22
    0x66554433,  # offset 0x7C - Sender MAC[2:5]: 33 44 55 66
    0x1032A8C0,  # offset 0x80 - Sender IP: C0 A8 32 10
    0xFF999D64,  # offset 0x84 - Target MAC[0:3]: 64 9D 99 FF
    0xA8C0EBEB,  # offset 0x88 - Target MAC[4:5] + Target IP[0:1]: EB EB C0 A8
    0x00000132,  # offset 0x8C - Target IP[2:3] + 2 zero pad: 32 01 00 00
    0x00000000,  # offset 0x90 - Padding
    0x00000000,  # offset 0x94 - Padding
    0x00000000,  # offset 0x98 - Padding
    0x00000000,  # offset 0x9C - Padding
    0x00000000,  # offset 0xA0 - Padding
]

# Default configuration, mirrors p11's `default_cfg`.
IFACE_MODE = {"lo":     {"cmac":{"ip": 0x7F000001, "ipv4": "127.0.0.1", "port": 5005, "mac": 0xFFFF_FFFF_FFFF},
                        "nic":{"ip": 0x7F000000, "ipv4": "127.0.0.0", "port": 0000, "mac": 0x0000_0000_0000}},
            "eth_qsfp1":{"cmac":{"ip": 0xC0A83210, "ipv4": "192.168.50.16", "port": 5005, "mac": 0x112233445566},
                        "nic":{"ip": 0xC0A83201, "ipv4": "192.168.50.1", "port": 5005, "mac": 0x649D99FFEBEB}}}


def swap_bytes32(v):
    return ((v & 0xFF) << 24) | ((v & 0xFF00) << 8) | ((v & 0xFF0000) >> 8) | ((v >> 24) & 0xFF)

def swap_bytes16(v):
    return ((v & 0xFF) << 8) | ((v >> 8) & 0xFF)


class rxtop:
    def __init__(self,ol):
        print("==== Configure RXTop ====")
        self.rxtop        = ol.rxtop_inst
        self.register_map = REG_MAP
        self.cfgs         = IFACE_MODE["eth_qsfp1"]
        self.write_axil("DBG_RXMODE",   0x00)
        self.write_axil("LOGGER_CLEAR", 0x00)
        self.cfg_iface()


    def cfg_iface(self):
        cmac_mac  = self.cfgs['cmac']['mac']
        nic_mac   = self.cfgs['nic']['mac']
        cmac_ip   = self.cfgs['cmac']['ip']
        nic_ip    = self.cfgs['nic']['ip']
        cmac_port = self.cfgs['cmac']['port']
        nic_port  = self.cfgs['nic']['port']

        write_cfgs = {
            "CMAC_MAC_15_00":    swap_bytes16(cmac_mac >> 32) & 0xFFFF,  #[4] and [5]
            "CMAC_MAC_31_16":    swap_bytes16(cmac_mac >> 16) & 0xFFFF, # [2] and [3]
            "CMAC_MAC_47_32":    swap_bytes16(cmac_mac >> 0) & 0xFFFF, # [0] and [1]
            "NIC_MAC_15_00":     swap_bytes16(nic_mac >> 32) & 0xFFFF,
            "NIC_MAC_31_16":     swap_bytes16(nic_mac >> 16) & 0xFFFF,
            "NIC_MAC_47_32":     swap_bytes16(nic_mac >> 0) & 0xFFFF,
            "MAC_TYPE":          0x0800,  # IPv4
            "IP_VERSION":        0x45,  # IPv4 + IHL=5
            "IP_PAYLOAD_LENGTH": 0,
            "IP_CHECKSUM":       0,
            "CMAC_IP":           swap_bytes32(cmac_ip),
            "NIC_IP":            swap_bytes32(nic_ip),
            "CMAC_PORT":         cmac_port,
            "NIC_PORT":          nic_port,
            "UDP_CHECKSUM":      0,
            "UDP_LENGTH":        0
        }
        for name, val in write_cfgs.items():
            self.rxtop.write(self.register_map[name], val.to_bytes(4, byteorder='little'))

    def bram_rd(self, nRead=16, verbose=False):
        nRow = nRead
        data = []
        self.rxtop.write(self.register_map[f"LOGGER_CLEAR"],1)
        for i in range(nRead):
            self.rxtop.write(self.register_map[f"LOGGER_RADDR"],i)
            for j in range(16): # each read will read 512Bytes:
                data.append(self.rxtop.read(self.register_map["LOGGER_RDOUT_S"]+j*4))
        if verbose:
            print("BRAM captured data: ")
            for i in range(0, len(data), 16):
                print(f"mem[{i}]={[hex(data[j+i*16]) for j in range(16)]}")        


    def write_axil(self, str_name, val):
        self.rxtop.write(self.register_map[f"{str_name}"],val)

    def read_axil(self, str_name):
        stt = self.rxtop.read(self.register_map[f"{str_name}"])
        print(f"{str_name}={stt}")
        return stt
    
    def status_update(self):
        print("Confirm Status Regs")
        for name, val in self.register_map.items():
            if not name.startswith("CUSTOM_ARP_REG"):
                stt = self.rxtop.read(self.register_map[f"{name}"])
                print(f"{name}: {hex(stt)}")