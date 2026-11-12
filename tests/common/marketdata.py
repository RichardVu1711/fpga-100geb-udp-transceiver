import pandas as pd
import numpy as np
from datetime import datetime
import struct



class market_info:
    def __init__(self,):
        self.stockid         = 0;
        self.open_val        = 0;
        self.high_val        = 0;
        self.low_val         = 0;
        self.close_val       = 0;
        self.volume_val      = 0;
        self.timestamp_val   = 0;
        self.spread          = 0;

    def getRowInfo(self, data_csv, rowIdx):
        self.stockid         = data_csv[rowIdx][1].encode('ascii').ljust(8, b'\x00')
        self.open_val        = data_csv[rowIdx][2]
        self.high_val        = data_csv[rowIdx][3]
        self.low_val         = data_csv[rowIdx][4]
        self.close_val       = data_csv[rowIdx][5]
        self.volume_val      = int(data_csv[rowIdx][6])
        self.timestamp_val   = int(datetime.strptime( data_csv[rowIdx][0],
                                    "%Y-%m-%d %H:%M:%S").timestamp())
        self.spread          = self.high_val - self.low_val
    def get_byte_msg(self, byte_form):
        msg = byte_form.stockid
        msg += byte_form.open_val
        msg += byte_form.high_val
        msg += byte_form.low_val
        msg += byte_form.close_val
        msg += byte_form.volume_val
        msg += byte_form.timestamp_val
        msg += byte_form.spread 
        return msg
    
    def to_byte_form(self, format="double"):
        byte_form = market_info()
        if(format == "double"):
            byte_form.stockid       = self.stockid
            byte_form.open_val      = struct.pack('<d',self.open_val);
            byte_form.high_val      = struct.pack('<d',self.high_val);
            byte_form.low_val       = struct.pack('<d',self.low_val);
            byte_form.close_val     = struct.pack('<d',self.close_val);
            byte_form.volume_val    = struct.pack('<d',int(self.volume_val));
            byte_form.timestamp_val = struct.pack('<Q',int(self.timestamp_val));
            byte_form.spread        = struct.pack('<d',self.spread);
        else:
            raise ValueError("The format is not defined")
        byte_msg = self.get_byte_msg(byte_form)
        return byte_form, byte_msg;

class stream_info:
    def __init__(self, csv_path=None):
        self.data_csv = pd.read_csv(csv_path).to_numpy()
        self.msg      = b'';
        self.infos    = [market_info()]# temporarily create 1 obj to initiate a list

    def reset_infos(self):
        self.infos    = [market_info() for i in range(len(self.infos))]

    def print_infos(self):
        print(f"Market Info table: stockid, open, high, low, close, volume, timestamp, and spread")
        for info in self.infos:
            str_info =  f"{info.stockid}, " + \
                        f"{info.open_val}, " + \
                        f"{info.high_val}, " + \
                        f"{info.low_val}, " + \
                        f"{info.close_val}, " + \
                        f"{info.volume_val}, " + \
                        f"{info.timestamp_val}, and " +\
                        f"{info.spread}"
            print(f"{str_info}")

    def to_axis_f(self, startIdx, nRows):
        if nRows > len(self.infos):
            # make bigger array
            self.infos = [market_info() for i in range(nRows)]

        byte_msg = b''
        for i in range(nRows):
            self.infos[i].getRowInfo(self.data_csv, startIdx + i)
            byte_form, msg = self.infos[i].to_byte_form(format="double")
            byte_msg += msg

        return self.infos, byte_msg
    