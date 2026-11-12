
import os

iface_mode = {"lo":     {"cmac":{"ip": 0x7F000001, "ipv4": "127.0.0.1", "port": 5005, "mac": 0xFFFF_FFFF_FFFF},
                        "nic":{"ip": 0x7F000000, "ipv4": "127.0.0.0", "port": 0000, "mac": 0x0000_0000_0000}},
            "eth_qsfp1": {"cmac":{"ip": 0xC0A83210, "ipv4": "192.168.50.16", "port": 5005, "mac": 0x1122_3344_5566},
                        "nic":{"ip": 0xC0A83201, "ipv4": "192.168.50.1", "port": 5005, "mac": 0x649D99FFEBEB}}}

sigs_lst = ["s00_axis", "m00_axis", "m01_axis", "m02_axis", \
            "m03_axis", "m04_axis", "m05_axis", "m06_axis", \
            "m07_axis", "marp_axis"]

AXI_REG_MAP = {
    "eth_cmac_mac_0" : 0x04,  # cmac_mac[15:0]
    "eth_cmac_mac_1" : 0x08,  # cmac_mac[31:16]
    "eth_cmac_mac_2" : 0x0C,  # cmac_mac[47:32]
    "eth_nic_mac_0"  : 0x10,  # nic_mac[15:0]
    "eth_nic_mac_1"  : 0x14,  # nic_mac[31:16]
    "eth_nic_mac_2"  : 0x18,  # nic_mac[47:32]
    "eth_mac_type"   : 0x1C,  # mac_type
    "ip4_version"    : 0x20,  # ip_version
    "ip4_length"     : 0x24,  # payload_length
    "ip4_checksum"   : 0x28,  # checksum
    "ip4_cmac_ip"    : 0x2C,  # cmac_ip
    "ip4_nic_ip"     : 0x30,  # nic_ip
    "udp_cmac_port"  : 0x34,  # cmac_port
    "udp_nic_port"   : 0x38,  # nic_port
    "udp_length"     : 0x3C,  # udp_length
    "udp_checksum"   : 0x40,  # udp_checksum
}


TX_REG_MAP = {
    "dbg_txmode"      : 0x00,
    "nic_mac_0"       : 0x04,  # nic_mac[15:0]
    "nic_mac_1"       : 0x08,  # nic_mac[31:16]
    "nic_mac_2"       : 0x0C,  # nic_mac[47:32]
    "cmac_mac_0"      : 0x10,  # cmac_mac[15:0]
    "cmac_mac_1"      : 0x14,  # cmac_mac[31:16]
    "cmac_mac_2"      : 0x18,  # cmac_mac[47:32]
    "mac_type"        : 0x1C,  # mac_type
    "ip4_version"     : 0x20,  # ip_version
    "ip4_dscp_ecn"    : 0x24,  # dscp_ecn
    "ip4_length"      : 0x28,  # ip4_len
    "ip4_identity"    : 0x2C,  # identity
    "ip4_flag_frag"   : 0x30,  # flag_frag
    "ip4_protocol"    : 0x34,  # time_proto
    "ip4_checksum"    : 0x38,  # ip4_checksum
    "ip4_cmac_ip"     : 0x3C,  # cmac_ip
    "ip4_nic_ip"      : 0x40,  # nic_ip
    "udp_cmac_port"   : 0x44,  # cmac_port
    "udp_nic_port"    : 0x48,  # nic_port
    "udp_length"      : 0x4C,  # udp_len
    "udp_checksum"    : 0x50,  # udp_checksum
}


PROJ_DIR = os.getenv("ENTRY")
