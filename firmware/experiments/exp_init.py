from pynq import Overlay
from pynq import allocate
from dma_cmac import dma_ctl, cmac_ctl
from firmware.rxtop import rxtop
from txtop import txtop
import sys
import os
import numpy as np
import time

def exp_init(bdfw):
    print("Finished Initialization")
    bdfw.rxtop.status_update()
    bdfw.txtop.status_update()

def exp_rx(bd_ctl):
    print("Benchmark RX side: Send continously and Receive the package continuously")
    bd_ctl.rxtop.write_axil("DBG_RXMODE", 0x00)
    bd_ctl.rxtop.status_update()
    ellapse = 0;
    # each element is 8bytes, there are 8 files => 64 b per frame => 5 frame per packet
    bufferA = allocate(shape = (10*32), dtype = np.uint64)
    bufferB = allocate(shape = (10*32), dtype = np.uint64)
    channel = bd_ctl.dma.dma_recv
    # Exit only after the timeout is reached
    timeout = 15
    nPkt = 100
    captured_pkt = []
    buf = bufferB; nxt_buf = bufferA
    cnt_display = 0
    tsleep  = 0.001
    isNoPacket = False
    step = 0;
    while isNoPacket==False:
        if step%1000 == 0:
            print(f"======Capturing {step}^th packet======")
        channel.transfer(buf)
        start_time = time.time()
        ellapse = 0
        while not channel.idle:
            ellapse = time.time() - start_time
            time.sleep(tsleep)
            if ellapse >= timeout:
                break
        # captured_pkt.append(buf.copy())
        if ellapse >= timeout: 
            isNoPacket = True
            break
        buf, nxt_buf = nxt_buf, buf
        step +=1
    bd_ctl.dma.dma_rxreset()
    # print(captured_pkt)
    print(f"receive {step} packets. Here is the status")
    bd_ctl.rxtop.status_update()

def exp_tx(bd_ctl):
    print("Benchmark TX side: Send continuously data from FPGA via CMAC")
    bd_ctl.txtop.write_axil("DBG_TXMODE", 0x00)
    bd_ctl.txtop.status_update()
    ellapse = 0