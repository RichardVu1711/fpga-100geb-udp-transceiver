module cdc_axil_regs 
import my_type::*;
(
      input  logic        axil_aclk, axil_aresetn,   // source-side clock, needed by the CDC primitive
      input  logic        axis_aclk, axis_aresetn,

      input  logic [7:0] dbg_mode,
      input  eth_t       eth_exp,
      input  ip4_t       ip4_exp,
      input  udp_t       udp_exp,

      output logic [7:0] dbg_mode_sync,
      output eth_t       eth_exp_sync,
      output ip4_t       ip4_exp_sync,
      output udp_t       udp_exp_sync
);
localparam FLAT_WIDTH = 8 + $bits(eth_t) + $bits(ip4_t) +  $bits(udp_t);

logic [FLAT_WIDTH-1:0] cfg_flat;
logic [FLAT_WIDTH-1:0] cfg_flat_sync;

assign cfg_flat = {dbg_mode, eth_exp, ip4_exp, udp_exp};
assign {dbg_mode_sync, eth_exp_sync, ip4_exp_sync, udp_exp_sync} = cfg_flat_sync;

`ifdef SYNTHESIS
xpm_cdc_array_single #(
    .WIDTH(FLAT_WIDTH),
    .DEST_SYNC_FF(3)
) cdc_eth_exp (
    .src_clk (axil_aclk),
    .src_in  (cfg_flat),        // packed struct → vector, implicit
    .dest_clk(axis_aclk),
    .dest_out(cfg_flat_sync)    // vector → packed struct, implicit
);
`else
always_ff @(posedge axis_aclk) begin
    cfg_flat_sync <= cfg_flat;
end
`endif


endmodule



