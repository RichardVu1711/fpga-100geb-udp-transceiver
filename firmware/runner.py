from pynq import Overlay
from board import board
from experiments.exp_init import *
import sys


if __name__ == "__main__":
    if len(sys.argv) > 1:
        args = sys.argv
        if args[1] == "i":
            print("Loading with bitstream")
            ol = Overlay('qsfp100g.xsa')
    else:
        print("loading without bitstream")
        ol = Overlay('qsfp100g.xsa', download=False)
    # will put arguments
    bd_fw = board(ol)
    exp_init(bd_fw)
    exp_rx(bd_fw)

    # dmaObj.getData(verbose=True)

    