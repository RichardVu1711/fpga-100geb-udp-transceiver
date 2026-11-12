#! /bin/bash

source /usr/local/share/pynq-venv/bin/activate
export XILINX_XRT=/usr

python3 runner.py "$@" 