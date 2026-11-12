#!/bin/sh
set -e

sudo cp 99-pynq.rules /etc/udev/rules.d/99-pynq.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usermod -aG kmem xilinx