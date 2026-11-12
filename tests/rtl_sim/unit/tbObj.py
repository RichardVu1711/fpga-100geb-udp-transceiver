import cocotb
from cocotb.triggers import Timer, with_timeout
from cocotbext.axi import AddressSpace, SparseMemoryRegion
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame, AxiBus, AxiLiteMaster, AxiSlave, AxiLiteBus)
from cocotb.triggers import RisingEdge, Event
from cocotb.triggers import RisingEdge, ReadOnly

import pandas as pd
import numpy as np
from datetime import datetime
import struct
import os
import ctypes


class uutObj:
    def __init__(self,dut, signals=None):
        self.dut = dut;
        print(f"list of signals: {signals}")
        self.clk_attrs  = [clk for clk in dir(dut) if clk.endswith("clk")]
        self.rst_attrs  = [rst for rst in dir(dut) if rst.endswith("aresetn")]
        self.src_signals = [s for s in signals if s.startswith("s")]
        self.dst_signals = [m for m in signals if m.startswith("m")]
        self.clks = [getattr(dut,f"{clk}") for clk in self.clk_attrs];
        self.rsts = [getattr(dut,f"{rst}") for rst in self.rst_attrs];

        self.axis_src = [AxiStreamSource(AxiStreamBus.from_prefix(dut, f"{s}"),
                                        self.clks[0], self.rsts[0],
                                        reset_active_level=False) 
                                        for s in self.src_signals]
        self.axis_dst = [AxiStreamSink(AxiStreamBus.from_prefix(dut, f"{m}"),
                                        self.clks[0], self.rsts[0],
                                        reset_active_level=False) 
                                        for m in self.dst_signals]        
        pass

    async def stream_monitor(self, signal, label=None):
        label = label or signal._name
        while True:
            await signal.value_change
            captured_data = signal.value.to_bytes(byteorder='little').hex()
            step = 32
            print(f"[{cocotb.utils.get_sim_time('ns')}ns]=============")
            for i in range(0, len(captured_data), step):
                pkt = captured_data[i:i+step]   # see bug note below
                print(f"\t{label}[{i/step}] = {pkt}")

    def no_backpressure(self):
        for m_axis in self.dst_signals:
            getattr(self.dut,f"{m_axis}_tready").value = 1

    async def clk_gen(self):
        while(True):
            for clk in self.clks: clk.value = 1;
            await Timer(5, unit="ns")
            for clk in self.clks: clk.value = 0;
            await Timer(5, unit="ns")

    async def tx_axis(self, msg, sig_idx=None):
        """msg is a series of bytes, msg = b''"""
        # create a frame of msg
        axis_frame = AxiStreamFrame(msg, tx_complete=Event())
        if sig_idx is None:
            # send to all source signals
            for i in range(len(self.axis_src)):
                await self.axis_src[i].send(msg)            
        else:
            #if sig_idx is a value:
            sig_idx = [sig_idx] if isinstance(sig_idx, int) else sig_idx
            [await self.axis_src[i].send(axis_frame) for i in sig_idx]
        return axis_frame  
          
    async def rx_axis(self, sig_idx=None):
        # create a frame of msg
        rev_stream = []
        if sig_idx is None:
            # send to all source signals
            sig_idx = range(len(self.axis_dst))
        else:
            #if sig_idx is a value:
            sig_idx = [sig_idx] if not isinstance(sig_idx, list) else sig_idx
        for i in sig_idx:
            tmp = await self.axis_dst[i].recv()
            rev_stream.append(tmp.tdata)
        return rev_stream        
    
    async def gen_resetn(self):
        for rst in self.rsts: rst.value = 1;
        await Timer(50, unit="ns")
        for rst in self.rsts: rst.value = 0;
        await Timer(50, unit="ns")
        for rst in self.rsts: rst.value = 1;
        pass
        
        