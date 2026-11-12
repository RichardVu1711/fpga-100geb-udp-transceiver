# TODO

## May not work
- ARP/UDP-TX arbitration not built — `sarp_axis` ignored outside debug mode `F1`. Scoped in `TXTop.sv:69-99`.
- `txtop_udp_tb.py` `cs_test0`: `udphdr`/`psdhdr`/`hdr_idx` slicing uses byte counts instead of word counts. Only survives because `nPkt=1`.
- **[CONFIRMED on hardware]** `udpcs_core.sv`: `first_pkt` state never checks `tlast` (only `middle_pkt` does) → UDP checksum gate rejects most real traffic. Measured: `DBG_RXMODE=0x20` (bypass) captures 99/100 real packets; normal mode (`0x00`) only passes `UDP_CHECKSUM_NPASS` ≈ 17-28/98 valid packets — the rest silently discarded by `gate_pkt_buffer`'s checksum gate, `IP_CHECKSUM_NPASS` unaffected (~100%). Real packets are ~9 beats (560B payload), not the 10-beat size assumed in sim. Next: confirm via ILA that `tlast` lands while `fsm_state==first_pkt` for these packets, then add a `tlast` check to that state.

## Could bite later
- `gate_tx_buffer.sv`: hardcoded full `tkeep` on payload beats — only correct because rows are exactly 64B. Breaks silently if payload framing changes.
- `gate_pkt_buffer.sv` (RX side): same hardcoded full-`tkeep`-on-output pattern as `gate_tx_buffer.sv`. Lower severity since PS firmware can rely on the header's own length field, but still not tracking the real `tkeep`.

## Cleanup
- `TXTop.sv:65-68`: stale TODO comment (ip4cs_latch/udpcs_latch race — already fixed).
- `create_tx_udp.sv`: `calhdr_info.ip4_len`/`.udp_len` never written.
- `ip4cs_core.sv`: dead `vld_pipe[1]`, shrink to 1 bit.
- `eth_demux.sv:162`: `udp_valid` → `arp_valid` typo (harmless in HW, still wrong).
