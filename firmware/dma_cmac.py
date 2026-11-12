from pynq import Overlay
from pynq import allocate
import time
import numpy as np

class dma_ctl:
    def __init__(self, ol):
        print("==== Configure DMA ====")
        self.dma = ol.dma;  
        self.dma_send = self.dma.sendchannel
        self.dma_recv = self.dma.recvchannel
        self.dma_allreset()
        self.dma_recv.start()
        self.outBuf = allocate(shape=(32*10,), dtype=np.uint32)
        self.inBuf = allocate(shape=(32*10,), dtype=np.uint32)

    def getData(self, verbose=False):
        if self.dma_poll("rx"):
            if verbose:
                self.print_rxBuf()
        return self.outBuf
    
    def sendData(self, txPkt=None, verbose=False):
        self.inBuf = self.inBuf if txPkt is None else txPkt
        self.dma_poll("tx")
        
    def dma_rxreset(self):
        self.dma.register_map.S2MM_DMACR.Reset = 1
        self.dma.recvchannel.start()

    def dma_allreset(self):
        self.dma.register_map.S2MM_DMACR.Reset = 1
        self.dma.register_map.MM2S_DMACR.Reset = 1
        self.dma_send.start()
        self.dma_recv.start()

    def dma_poll(self, side="rx"):
        timeout = 30.0
        tsleep  = 0.001
        ellapse = 0.0
        if side == "rx":
            buf     = self.outBuf
            channel = self.dma_recv
        elif side == "tx":
            buf     = self.inBuf
            channel = self.dma_send
        else:
            raise ValueError("Invalid side")
        channel.transfer(buf)
        print(f'Polling the system for {timeout}s')
        start_time = time.time()
        while not channel.idle:
            ellapse = time.time() - start_time
            time.sleep(tsleep)
            if ellapse >= timeout:
                break
        # Reset the dma for the next catch
        if side == "rx":
            self.dma_rxreset()
        if(ellapse <= timeout):
            print(f'Finish {side} at t={timeout-ellapse}')
            return True
        else:
            return False

    def print_rxBuf(self):
        print(f"The receive buffer={[hex(val) for val in self.outBuf]}")


class cmac_ctl:
    def __init__(self,ol):
        print("==== Configure CMAC with allignment ====")

        self.cmac = ol.cmac;
        # Setup RSFEC
        self.cmac.write(0x107C, 0x3)
        self.cmac.write(0x1000, 0x7)

        # Setup TX
        self.cmac.register_map.conf_tx = 0x10

        # Enable RX
        self.cmac.register_map.conf_rx = 0x01

        # Check RX aligned
        print("CAMC: Waiting for RX aligned. Usually takes 30s")
        waiting_time = 0
        timeout = 30
        while not self.cmac_is_aligned():
            if waiting_time < timeout:
                time.sleep(1)
                waiting_time += 1
                print(f'{waiting_time}s/{timeout}s...')
            elif timeout > 0:
                raise RuntimeError("Receive channel not aligned")

        if self.cmac_is_aligned():
            print("CMAC: RX aligned")
            # Enable TX
            self.cmac.register_map.conf_tx = 0x01
        else:
            print("CMAC: ERROR RX not aligned")

    def reset(self):
        self.cmac.register_map.conf_tx = 0x01
        self.cmac.write(0x0004, 0xC0000000)
        self.cmac.write(0x0004, 0x00000000)
        self.cmac.write(0x0000, 1)
        
    def cmac_is_aligned(self):
        status = self.cmac.register_map.stat_rx_status[1]
        print(f'RX Current Status = {status}')
        return status