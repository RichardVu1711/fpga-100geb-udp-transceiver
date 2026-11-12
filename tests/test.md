tests/
    common/                     # shared, hardware-agnostic code — used by BOTH rtl_sim and firmware
      checksum_ref.py           # golden Python model of ip4/udp checksum (RFC1071) — one source of truth
      packet_builders.py        # ARP/UDP/IPv4 frame construction
      byte_utils.py             # swap_bytes16/32, hex reversal
      fixtures/                 # iladata.csv, iladata_stupid.csv — canned captures

    rtl_sim/                    # cocotb — needs verilator, no board
      tbObj.py                  # uutObj base class (clk/reset fix lives here)
      unit/                     # one DUT per file, isolated
        ip4_checksum_tb.py
        udp_checksum_tb.py
        axis_pkt_buffer_tb.py
      integration/               # full XCVC/RXTop pipeline
        xcvc_config_tb.py
        xcvc_checksum_tb.py
        xcvc_arp_tb.py

    firmware/                   # pytest — pure Python, no board, no simulator
      conftest.py                # fake_overlay fixture (mocked dma/cmac/register_map)
      test_dma_ctl.py
      test_cmac_ctl.py
      test_xcvc_driver.py
      test_runner_args.py
      test_hw_udp_encoding.py    # crt_byte_array/stockFloatBytes only — no socket

    hw_in_loop/                 # needs the real rf_4x2 board + link partner
      hw_udp.py
      exam_udp.py