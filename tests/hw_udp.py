import os
from pathlib import Path
import pandas as pd
import numpy as np
import time
from datetime import datetime
import struct
from scapy.all import Ether, IP, UDP, sendp, sniff, AsyncSniffer
import socket

ROOT_DIR = Path(os.environ.get("ROOT_DIR", os.getcwd()))
iface_mode = {"lo": {"dst":{"ip": 0x7F000001, "ipv4": "127.0.0.1", "port": 5005, "mac": 0xFFFF_FFFF_FFFF},
                    "src":{"ip": 0x00000000, "ipv4": "0.0.0.0", "port": 0000, "mac": 0x0000_0000_0000}},
            "eth_qsfp1": {"dst":{"ip": 0xC0A83210, "ipv4": "192.168.50.16", "port": 5005, "mac": 0x1122_3344_5566},
                    "src":{"ip": 0xC0A83201, "ipv4": "192.168.50.1", "port": 5005, "mac": 0x649d_99ff_ebeb}}}
class stockInfo:
    def __init__(self):
        self.stockid       = 0;
        self.open_val      = 0;
        self.high_val      = 0;
        self.low_val       = 0;
        self.close_val     = 0;
        self.volume_val    = 0;
        self.timestamp_val = 0;
        self.spread        = 0;

class stockFloatBytes:
    def __init__(self, stkInfo, size_b):
        self.byte_size       = size_b;
        if stkInfo is not None:
            self.to_bytes(stkInfo)
        else:
            self.stockid       = 0;
            self.open_val      = 0;
            self.high_val      = 0;
            self.low_val       = 0;
            self.close_val     = 0;
            self.volume_val    = 0;
            self.timestamp_val = 0;
    def to_bytes(self, stkInfo):
        self.stockid         = stkInfo.stockid.encode('ascii').ljust(self.byte_size, b'\x00')
        self.open_val        = struct.pack('<d', stkInfo.open_val)
        self.high_val        = struct.pack('<d', stkInfo.high_val)
        self.low_val         = struct.pack('<d', stkInfo.low_val)
        self.close_val       = struct.pack('<d', stkInfo.close_val)
        self.volume_val      = struct.pack('<Q', stkInfo.volume_val)
        self.timestamp_val   = struct.pack('<Q', stkInfo.timestamp_val)

class hostUDP:
    def __init__(self, csv_path, perRow=1):
        self.csv_path = csv_path
        self.df = pd.read_csv(csv_path)
        self.perRow = perRow;
        self.stockInfoList = []
        self.encode8List = []
        self.payload = b''
        for index, row in self.df.iterrows():
            stock = stockInfo()
            stock.stockid = row['symbol']
            stock.open_val = row['open']
            stock.high_val = row['high']
            stock.low_val = row['low']
            stock.close_val = row['close']
            stock.volume_val = int(row['volume'])
            stock.timestamp_val = int(datetime.strptime(row['timestamp'], "%Y-%m-%d %H:%M:%S").timestamp())
            stock.spread = stock.high_val - stock.low_val

            stockInbytes = stockFloatBytes(stock, 8)
            self.stockInfoList.append(stock)
            self.encode8List.append(stockInbytes)

    def crt_byte_array(self, sRow):
        payload = b''
        for j in range(self.perRow):
            stockInbytes = self.encode8List[sRow + j]
            payload += stockInbytes.stockid
            payload += stockInbytes.open_val
            payload += stockInbytes.high_val
            payload += stockInbytes.low_val
            payload += stockInbytes.close_val
            payload += stockInbytes.volume_val
            payload += stockInbytes.timestamp_val
        return payload
    
    def send_udp_packets(self, iface, n_row, sRow, modeLib="socket"):
        if modeLib == "socket":
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            try:
                sock.bind((iface_mode[iface]["src"]["ipv4"], iface_mode[iface]["src"]["port"]))
                print(f"Bound to {iface_mode[iface]['src']['ipv4']}")
            except OSError as e:
                print(f"Bind failed: {e}")
        for i in range(n_row):
            payload = self.crt_byte_array(sRow + i*3)
            if modeLib == "socket":
                # sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
                sock.sendto(payload, (iface_mode[iface]["dst"]["ipv4"], iface_mode[iface]["dst"]["port"]))
            else:
                # using scapy to send the packet
                packet = Ether(dst=iface_mode[iface]["dst"]["mac"]) /\
                        IP(dst=iface_mode[iface]["dst"]["ipv4"]) / \
                        UDP(dport=iface_mode[iface]["dst"]["port"]) /\
                        payload
                sendp(packet, iface=iface, verbose=False)
            self.payload += payload
            # time.sleep(0.01)  # Sleep for 10ms between packets
            # print(f"Sent packet {i+1}/{n_row} with payload: {payload.hex()}")
        if modeLib == "socket":
            sock.close()

if __name__ == "__main__":
    csv_path = f"{ROOT_DIR}/data/sharedtest/AAPL_aggs_2026-01-01_2026-03-01.csv"
    host = hostUDP(csv_path, perRow=20)
    host.send_udp_packets("eth_qsfp1", 100, 0, modeLib="socket")  # Send 10 rows starting from row
    print(f"Sent payload: {host.payload}")