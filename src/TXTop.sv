
module TXTop
import my_type::*;
#(
    // Width of data bus in bits
    parameter AXIL_DWIDTH  = 32,
    // Width of address bus in bits
    parameter AXIL_AWIDTH  = 32,
    parameter S_AXIS_WIDTH = 512,
    parameter M_AXIS_WIDTH = 512
)
(
    input  wire                           axil_aclk,
    input  wire                           axil_aresetn,
    input  wire                           axis_aclk,
    input  wire                           axis_aresetn,
    /*
     * AXI Stream interface, comes from the DMA
     */
    output logic                          s00_axis_tready,
    input  logic [S_AXIS_WIDTH-1 : 0    ] s00_axis_tdata,
    input  logic [(S_AXIS_WIDTH/8)-1 : 0] s00_axis_tkeep,
    input  logic                          s00_axis_tlast,
    input  logic                          s00_axis_tvalid,
    
    /*
     * AXI Stream interface
     */
    output logic                          sarp_axis_tready,
    input  logic [S_AXIS_WIDTH-1 : 0    ] sarp_axis_tdata,
    input  logic [(S_AXIS_WIDTH/8)-1 : 0] sarp_axis_tkeep,
    input  logic                          sarp_axis_tlast,
    input  logic                          sarp_axis_tvalid,

    /** Output Streams **/
    output logic [M_AXIS_WIDTH-1 : 0]     m00_axis_tdata,
    output logic [(M_AXIS_WIDTH/8)-1 : 0] m00_axis_tkeep,
    output logic                          m00_axis_tlast,
    output logic                          m00_axis_tvalid,
    input  logic                          m00_axis_tready,

    /*
     * AXI-Lite slave interface
     */
    input  logic [AXIL_AWIDTH-1:0]        s_axil_awaddr,
    input  logic [2:0]                    s_axil_awprot,
    input  logic                          s_axil_awvalid,
    output logic                          s_axil_awready,
    input  logic [AXIL_DWIDTH-1:0]        s_axil_wdata,
    input  logic [(AXIL_DWIDTH)/8-1:0]    s_axil_wstrb,
    input  logic                          s_axil_wvalid,
    output logic                          s_axil_wready,
    output logic [1:0]                    s_axil_bresp,
    output logic                          s_axil_bvalid,
    input  logic                          s_axil_bready,
    input  logic [AXIL_AWIDTH-1:0]        s_axil_araddr,
    input  logic [2:0]                    s_axil_arprot,
    input  logic                          s_axil_arvalid,
    output logic                          s_axil_arready,
    output logic [AXIL_DWIDTH-1:0]        s_axil_rdata,
    output logic [1:0]                    s_axil_rresp,
    output logic                          s_axil_rvalid,
    input  logic                          s_axil_rready         
);
// TODO: create_tx_udp.sv: fix ip4cs_latch/udpcs_latch race on back-to-back
//      packets (esp. short ones) — same as before.
//      gate_tx_buffer.sv: drop unused calhdr_info port (rd_en IS used,
//       keep it — wired to crt_tx_udp.hdr_vld).
// TODO: (real ARP/UDP-TX arbitration, replacing the arp -s workaround):
//   [ ] eth_demux.sv: fix ARP output framing first (prerequisite — no point
//       arbitrating a signal that's still broken):
//       - line 162: `udp_valid` -> `arp_valid` (copy-paste typo)
//       - bound marp_axis_tvalid/tlast to exactly ONE beat per ARP request,
//         instead of staying stuck asserted until some unrelated future
//         s00_axis_tlast. The existing arp_reply_pending/tmp_cnt logic
//         (lines 107-125) looks like an abandoned attempt at this — either
//         finish wiring it into the marp_axis_* mux, or replace with a
//         simple one-shot pulse gated on states entering passing_arp.
//   [ ] gate_tx_buffer.sv: expose an "idle"/"busy" status output derived
//       from rd_stt (e.g. output logic rd_idle = (rd_stt == 0)), so TXTop
//       can observe whether a UDP packet read is currently in flight.
//   [ ] TXTop.sv: add a 1-entry latch for a pending ARP reply. Since
//       sarp_axis_tready is hardwired to 1 (no backpressure), a sarp beat
//       arriving while gate_tx_buffer is busy would otherwise be silently
//       lost if the arbiter can't take it that cycle — latch
//       sarp_axis_tdata/tkeep + a pending flag on arrival if not
//       immediately consumable.
//   [ ] TXTop.sv: build the actual arbiter for m00_axis:
//       - if arp_pending && gate_tx_buffer's rd_idle: emit the latched ARP
//         beat (1 cycle, tlast=1), clear arp_pending
//       - else: pass through udp_axis as today
//       - make sure this doesn't race with gate_tx_buffer's own state-0
//         trigger (q_rd_ptr != wr_hdr_qptr) — the ARP insertion and a new
//         packet's header-beat start shouldn't both fire the same cycle.
//   [ ] Sim test: (a) ARP arrives while idle -> passes immediately,
//       (b) ARP arrives mid-packet -> queued, drained cleanly right after
//       current packet's tlast, no truncation of either stream,
//       (c) back-to-back UDP packets with no ARP present -> arbiter is a
//       no-op, unchanged behavior from today.


// constant variable
localparam BUFFER_AWIDTH = 8;
// configure registers
udp_tx_t    hdr_info;
// ==== Debug signals ====
// This is used as a prober, where at each mode, the corresponding output is passed
// Mode 2x: test mode for gate_tx_buffer
//      20: pass the input directly to the output
// Mode fx: test mode for TXTop
//      f0: pass the input s00 directly to the output
//      f1: pass the input sarp directly to the output
logic [7:0]                    dbg_txmode;

// ==== Intermediate Wires ====
logic [M_AXIS_WIDTH-1 : 0]     b_axis_tdata;
logic [(M_AXIS_WIDTH/8)-1 : 0] b_axis_tkeep;
logic                          b_axis_tlast;
logic                          b_axis_tvalid;
logic                          b_axis_tready;

logic [M_AXIS_WIDTH-1 : 0]     udp_axis_tdata;
logic [(M_AXIS_WIDTH/8)-1 : 0] udp_axis_tkeep;
logic                          udp_axis_tlast;
logic                          udp_axis_tvalid;
logic                          udp_axis_tready;

logic                          hdr_vld; // For the moment
hdrtx_cal_t                    calhdr_info;

gate_tx_buffer#(
    .AXIS_WIDTH(M_AXIS_WIDTH),
    .ADDR_WIDTH(BUFFER_AWIDTH)
) csgate_tx (
    .aclk(axis_aclk),
    .aresetn(axis_aresetn),
    /** Header Info **/
    .hdr_info(hdr_info),
    .calhdr_info(calhdr_info),

    /** Flag signals**/
    .dbg_txmode(dbg_txmode),
    .rd_en(hdr_vld),
    /** Input Streams **/
    .s00_axis_tdata(s00_axis_tdata),
    .s00_axis_tkeep(s00_axis_tkeep),
    .s00_axis_tlast(s00_axis_tlast),
    .s00_axis_tvalid(s00_axis_tvalid),
    /* verilator lint_off PINCONNECTEMPTY */
    .s00_axis_tready(),
    /* verilator lint_on PINCONNECTEMPTY */
    
    /** Output Streams **/
    .m00_axis_tdata(udp_axis_tdata),
    .m00_axis_tkeep(udp_axis_tkeep),
    .m00_axis_tlast(udp_axis_tlast),
    .m00_axis_tvalid(udp_axis_tvalid),
    .m00_axis_tready(udp_axis_tready)
);

create_tx_udp#(
    .AXIS_WIDTH(M_AXIS_WIDTH)
) crt_tx_udp (
    .aclk(axis_aclk),
    .aresetn(axis_aresetn),
    /** Configure Registers**/
    .hdr_info(hdr_info),
    
    /* AXI Stream interface, come from the DMA */
    .s00_axis_tdata(s00_axis_tdata),
    .s00_axis_tkeep(s00_axis_tkeep),
    .s00_axis_tlast(s00_axis_tlast),
    .s00_axis_tvalid(s00_axis_tvalid),

    /* verilator lint_off PINCONNECTEMPTY */
    .s00_axis_tready(),
    /* verilator lint_on PINCONNECTEMPTY */
    .hdr_vld(hdr_vld),
    .calhdr_info(calhdr_info)
);



// Need to remove these buses they are part of read/write axil regs
logic [AXIL_AWIDTH-1:0]     reg_wr_addr;
logic [AXIL_DWIDTH-1:0]     reg_wr_data;
logic [(AXIL_DWIDTH)/8-1:0] reg_wr_strb;
logic                       reg_wr_en;
logic                       reg_wr_wait;
logic                       reg_wr_ack;
logic [AXIL_AWIDTH-1:0]     reg_rd_addr;
logic                       reg_rd_en;
logic [AXIL_DWIDTH-1:0 ]    reg_rd_data;
logic                       reg_rd_wait;
logic                       reg_rd_ack;    
logic [AXIL_AWIDTH-1:0]     masked_wr_addr; 
logic [AXIL_AWIDTH-1:0]     masked_rd_addr; 

assign masked_wr_addr = reg_wr_addr & 32'h0000FFFF;
assign masked_rd_addr = reg_rd_addr & 32'h0000FFFF;
// AXI Lite Read: read from some rtl regs. I may need to use xilinx cdc ip core here ....
always_comb begin
    case(masked_rd_addr)
    // 0-100: This is for configuration registers
        32'h0:  begin reg_rd_data[7:0]  = dbg_txmode; end
        32'h4:  begin reg_rd_data[15:0] = hdr_info.nic_mac[15:0]; end
        32'h8:  begin reg_rd_data[15:0] = hdr_info.nic_mac[31:16]; end
        32'hC:  begin reg_rd_data[15:0] = hdr_info.nic_mac[47:32]; end
        32'h10: begin reg_rd_data[15:0] = hdr_info.cmac_mac[15:0]; end
        32'h14: begin reg_rd_data[15:0] = hdr_info.cmac_mac[31:16]; end
        32'h18: begin reg_rd_data[15:0] = hdr_info.cmac_mac[47:32]; end
        32'h1C: begin reg_rd_data[15:0] = hdr_info.mac_type; end
        32'h20: begin reg_rd_data[7:0]  = hdr_info.ip_version;end
        32'h24: begin reg_rd_data[7:0]  = hdr_info.dscp_ecn;end
        32'h28: begin reg_rd_data[15:0] = hdr_info.ip4_len; end
        32'h2C: begin reg_rd_data[15:0] = hdr_info.identity; end
        32'h30: begin reg_rd_data[15:0] = hdr_info.flag_frag; end
        32'h34: begin reg_rd_data[15:0] = hdr_info.time_proto; end
        32'h38: begin reg_rd_data[15:0] = hdr_info.ip4_checksum; end
        32'h3C: begin reg_rd_data[31:0] = hdr_info.cmac_ip; end
        32'h40: begin reg_rd_data[31:0] = hdr_info.nic_ip; end
        32'h44: begin reg_rd_data[15:0] = hdr_info.cmac_port; end
        32'h48: begin reg_rd_data[15:0] = hdr_info.nic_port; end
        32'h4C: begin reg_rd_data[15:0] = hdr_info.udp_len; end
        32'h50: begin reg_rd_data[15:0] = hdr_info.udp_checksum; end
    default: begin reg_rd_data = {32'hDEADBEEF}; reg_rd_ack = 1'b0; end
    endcase
end


always_ff @(posedge axil_aclk) begin
    if (!axil_aresetn) begin
        // reset defaults here
        dbg_txmode <= 8'h0;
        hdr_info   <= 0;
    end else begin 
        if (reg_wr_en) begin
            case(masked_wr_addr)
                32'h0:  begin dbg_txmode               <= reg_wr_data[7:0]; end
                32'h4:  begin hdr_info.nic_mac[15:0]   <= reg_wr_data[15:0]; end
                32'h8:  begin hdr_info.nic_mac[31:16]  <= reg_wr_data[15:0]; end
                32'hC:  begin hdr_info.nic_mac[47:32]  <= reg_wr_data[15:0]; end
                32'h10: begin hdr_info.cmac_mac[15:0]  <= reg_wr_data[15:0]; end
                32'h14: begin hdr_info.cmac_mac[31:16] <= reg_wr_data[15:0]; end
                32'h18: begin hdr_info.cmac_mac[47:32] <= reg_wr_data[15:0]; end
                32'h1C: begin hdr_info.mac_type        <= reg_wr_data[15:0]; end
                32'h20: begin hdr_info.ip_version      <= reg_wr_data[7:0]; end
                32'h24: begin hdr_info.dscp_ecn        <= reg_wr_data[7:0]; end
                32'h28: begin hdr_info.ip4_len         <= reg_wr_data[15:0]; end
                32'h2C: begin hdr_info.identity        <= reg_wr_data[15:0]; end
                32'h30: begin hdr_info.flag_frag       <= reg_wr_data[15:0]; end
                32'h34: begin hdr_info.time_proto      <= reg_wr_data[15:0]; end
                32'h38: begin hdr_info.ip4_checksum    <= reg_wr_data[15:0]; end
                32'h3C: begin hdr_info.cmac_ip         <= reg_wr_data[31:0]; end
                32'h40: begin hdr_info.nic_ip          <= reg_wr_data[31:0]; end
                32'h44: begin hdr_info.cmac_port       <= reg_wr_data[15:0]; end
                32'h48: begin hdr_info.nic_port        <= reg_wr_data[15:0]; end
                32'h4C: begin hdr_info.udp_len         <= reg_wr_data[15:0]; end
                32'h50: begin hdr_info.udp_checksum    <= reg_wr_data[15:0]; end
                // default: Do nothing 
            endcase
        end
    end
end



axil_reg_if#(
    .DATA_WIDTH(AXIL_DWIDTH),
    .ADDR_WIDTH(AXIL_AWIDTH),
    .STRB_WIDTH(AXIL_DWIDTH/8),
    .TIMEOUT(4)
)
axil_adapter(
    .clk(axil_aclk),
    .rst(!axil_aresetn),
    
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),

    .reg_wr_addr(reg_wr_addr),
    .reg_wr_data(reg_wr_data),
    .reg_wr_strb(reg_wr_strb),
    .reg_wr_en(reg_wr_en),
    .reg_wr_wait(reg_wr_wait),
    .reg_wr_ack(reg_wr_ack),
    .reg_rd_addr(reg_rd_addr),
    .reg_rd_en(reg_rd_en),
    .reg_rd_data(reg_rd_data),
    .reg_rd_wait(reg_rd_wait),
    .reg_rd_ack(reg_rd_ack)
);

// no backpressure
assign s00_axis_tready = 1;
assign sarp_axis_tready = 1;

// Debugging
always_comb begin
    if(dbg_txmode == 8'hF0) begin
        // By pass the input to the output
        m00_axis_tdata  = s00_axis_tdata;
        m00_axis_tkeep  = s00_axis_tkeep;
        m00_axis_tlast  = s00_axis_tlast;
        m00_axis_tvalid = s00_axis_tvalid;
        
    end else if(dbg_txmode == 8'hF1) begin
        m00_axis_tdata  = sarp_axis_tdata;
        m00_axis_tkeep  = sarp_axis_tkeep;
        m00_axis_tlast  = sarp_axis_tlast;
        m00_axis_tvalid = sarp_axis_tvalid;
    end else begin
        m00_axis_tdata  = udp_axis_tdata;
        m00_axis_tkeep  = udp_axis_tkeep;
        m00_axis_tlast  = udp_axis_tlast;
        m00_axis_tvalid = udp_axis_tvalid;
    end

end
endmodule

