# fpga-100g-udp-offload

FPGA UDP/IP receive and transmit logic for a 100G Ethernet (CMAC) link, with a PYNQ-based Python firmware layer and cocotb RTL testbenches.

## Layout
- `src/` – SystemVerilog RTL (`RXTop`, `TXTop`, ARP/Ethernet demux, IP/UDP checksum cores, packet gates, AXI-Lite registers)
- `firmware/` – PYNQ Python drivers (`rxtop.py`, `txtop.py`, DMA/CMAC helpers)
- `tests/` – cocotb RTL simulation (`rtl_sim/`) and hardware-side UDP tests
- `scripts/` – Vivado Tcl, constraints, cocotb Makefile
- `hw_make.sh`, `sim_make.sh` – hardware build and simulation entry points
- `llama311.yml` – conda environment used for the Python tooling

## Status
Multiple frames have been transmitted and received on hardware. Stress testing is limited because the DMA firmware is minimal.
Known issues and planned work are tracked openly in [TODO.md](TODO.md), including a hardware-confirmed UDP checksum gate bug.
Note: I'm not sure whether that bug has since been fixed, so the TODO may be out of date.
