IFACE_MODE = {"lo":     {"cmac":{"ip": 0x7F000001, "ipv4": "127.0.0.1", "port": 5005, "mac": 0xFFFF_FFFF_FFFF},
                        "nic":{"ip": 0x7F000000, "ipv4": "127.0.0.0", "port": 0000, "mac": 0x0000_0000_0000}},
            "eth_qsfp1":{"cmac":{"ip": 0xC0A83210, "ipv4": "192.168.50.16", "port": 5005, "mac": 0x112233445566},
                        "nic":{"ip": 0xC0A83201, "ipv4": "192.168.50.1", "port": 5005, "mac": 0x649D99FFEBEB}}}


def swap_bytes32(v):
    return ((v & 0xFF) << 24) | ((v & 0xFF00) << 8) | ((v & 0xFF0000) >> 8) | ((v >> 24) & 0xFF)

def swap_bytes16(v):
    return ((v & 0xFF) << 8) | ((v >> 8) & 0xFF)