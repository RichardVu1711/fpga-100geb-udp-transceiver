from pynq import Overlay
from dma_cmac import dma_ctl, cmac_ctl
from firmware.rxtop import rxtop
from txtop import txtop
from experiments.exp_init import *
import sys

class board:
    def __init__(self,ol):
        self.cmac = cmac_ctl(ol)
        self.dma = dma_ctl(ol)
        self.rxtop = rxtop(ol)
        self.txtop = txtop(ol)
        pass