module RXTop
import my_type::*;
#(
    // Width of data bus in bits
    parameter AXIL_DWIDTH  = 32,
    // Width of address bus in bits
    parameter AXIL_AWIDTH  = 32,
    parameter S_AXIS_WIDTH = 512,
    parameter M_AXIS_WIDTH = 512
)(
    input  logic                          axil_aclk,
    input  logic                          axil_aresetn,
    input  logic                          axis_aclk,
    input  logic                          axis_aresetn,
    /** Status Register **/
    output logic [7:0]                   debug_prob,
    output logic [1:0]                   demux_type,

    /** Input Streams **/
    input  logic [S_AXIS_WIDTH-1 : 0 ]    s00_axis_tdata,
    input  logic [(S_AXIS_WIDTH/8)-1 : 0] s00_axis_tkeep,
    input  logic                          s00_axis_tlast,
    input  logic                          s00_axis_tvalid,
    output logic                          s00_axis_tready,
    /** Output Streams **/
    output logic [M_AXIS_WIDTH-1 : 0]     marp_axis_tdata,
    output logic [(M_AXIS_WIDTH/8)-1 : 0] marp_axis_tkeep,
    output logic                          marp_axis_tlast,
    output logic                          marp_axis_tvalid,
    input  logic                          marp_axis_tready,

    output logic [M_AXIS_WIDTH-1 : 0]     m00_axis_tdata,
    output logic [(M_AXIS_WIDTH/8)-1 : 0] m00_axis_tkeep,
    output logic                          m00_axis_tlast,
    output logic                          m00_axis_tvalid,
    input  logic                          m00_axis_tready,
    
    /** AXI-Lite slave interface **/
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
localparam CSGATE_ADDR_WIDTH = 8;
// ==== Debug signals ====
// This is used as a prober, where at each mode, the corresponding output is passed
// Mode 1x: test mode for eth_demux
//      10: pass the input directly to the output
//      11: pass the custom_arp_reg to the output
// Mode 2x: test mode for csgate_buffer
//      20: pass the input directly to the output
// Mode fx: test mode for RXTop
//      f0: pass the input directly to the output
logic [7:0] dbg_rxmode;
logic [7:0] dbg_rxmode_sync;
assign debug_prob = dbg_rxmode;
// ==== Real Signal ====
// ==== Status Register ====
eth_t eth_cap;
ip4_t ip4_cap;
udp_t udp_cap;
// parameter to pass through model
eth_t eth_exp;
ip4_t ip4_exp;
udp_t udp_exp;

eth_t eth_exp_sync;
ip4_t ip4_exp_sync;
udp_t udp_exp_sync;

logic [M_AXIS_WIDTH-1:0]       custom_arp_reg;
logic [BYTES*2:0]              ip4cs_stat;
logic [BYTES*2:0]              udpcs_stat;

logic [CSGATE_ADDR_WIDTH-1:0]  gate_mm_gap;     
logic [16-1:0]                 csfailed_cnt;
logic                          logger_clear;
logic [LOGGER_AWIDTH-1:0]      logger_rAddr;
logic [M_AXIS_WIDTH-1:0]       logger_rDout;

logic [M_AXIS_WIDTH-1 : 0 ]    csgate_axis_tdata;
logic [(M_AXIS_WIDTH/8)-1 : 0] csgate_axis_tkeep;
logic                          csgate_axis_tlast;
logic                          csgate_axis_tvalid;

logic [M_AXIS_WIDTH-1 : 0 ]    udp_axis_tdata;
logic [(M_AXIS_WIDTH/8)-1 : 0] udp_axis_tkeep;
logic                          udp_axis_tlast;
logic                          udp_axis_tvalid;

logic [M_AXIS_WIDTH-1 : 0]     arp_axis_tdata;
logic [(M_AXIS_WIDTH/8)-1 : 0] arp_axis_tkeep;
logic                          arp_axis_tlast;
logic                          arp_axis_tvalid;

logic [2*BYTES-1:0]            ip4cs;
logic                          ip4cs_vld;
logic [2*BYTES-1:0]            udpcs;
logic                          udpcs_vld;
// Will have  probe logic to measure the gap between pkt here
logic [4*BYTES-1:0]            gap_between_pkts;
logic                          gap_pkts_vld;

always_comb begin
    if(dbg_rxmode == 8'hf0) begin
        m00_axis_tdata   = s00_axis_tdata;
        m00_axis_tkeep   = s00_axis_tkeep;
        m00_axis_tvalid  = s00_axis_tvalid;
        m00_axis_tlast   = s00_axis_tlast;

        marp_axis_tdata  = s00_axis_tdata;
        marp_axis_tkeep  = s00_axis_tkeep;
        marp_axis_tvalid = s00_axis_tvalid;
        marp_axis_tlast  = s00_axis_tlast;
    end else begin
        m00_axis_tdata   = csgate_axis_tdata;
        m00_axis_tkeep   = csgate_axis_tkeep;
        m00_axis_tvalid  = csgate_axis_tvalid;
        m00_axis_tlast   = csgate_axis_tlast;

        marp_axis_tdata  = arp_axis_tdata;
        marp_axis_tkeep  = arp_axis_tkeep;
        marp_axis_tvalid = arp_axis_tvalid;
        marp_axis_tlast  = arp_axis_tlast;
    end
end

eth_demux#(
    .S_AXIS_WIDTH(S_AXIS_WIDTH),
    .M_AXIS_WIDTH(M_AXIS_WIDTH)
) eth_demux_inst (
    .clk(axis_aclk),
    .aresetn(axis_aresetn),

    .eth_exp(eth_exp_sync),
    .ip4_exp(ip4_exp_sync),
    .udp_exp(udp_exp_sync),
    .dbg_rxmode(dbg_rxmode),
    .custom_arp_reg(custom_arp_reg),

    .demux_type(demux_type),
    .eth_cap(eth_cap),
    .ip4_cap(ip4_cap),
    .udp_cap(udp_cap),

    .s00_axis_tdata(s00_axis_tdata),
    .s00_axis_tkeep(s00_axis_tkeep),
    .s00_axis_tlast(s00_axis_tlast),
    .s00_axis_tvalid(s00_axis_tvalid),
    /* verilator lint_off PINCONNECTEMPTY */
    .s00_axis_tready(),
    /* verilator lint_on PINCONNECTEMPTY */

    .mudp_axis_tdata(udp_axis_tdata),
    .mudp_axis_tkeep(udp_axis_tkeep),
    .mudp_axis_tlast(udp_axis_tlast),
    .mudp_axis_tvalid(udp_axis_tvalid),
    /* verilator lint_off PINCONNECTEMPTY */
    .mudp_axis_tready(),
    /* verilator lint_on PINCONNECTEMPTY */

    .marp_axis_tdata(arp_axis_tdata),
    .marp_axis_tkeep(arp_axis_tkeep),
    .marp_axis_tlast(arp_axis_tlast),
    .marp_axis_tvalid(arp_axis_tvalid),
    /* verilator lint_off PINCONNECTEMPTY */
    .marp_axis_tready()
    /* verilator lint_on PINCONNECTEMPTY*/
);

check_rx_udp#(
    .AXIS_WIDTH(S_AXIS_WIDTH)
) cs_rx_udp (
    .aclk(axis_aclk),
    .aresetn(axis_aresetn),
    
    // streaming input (tap off the real data path, doesn't gate tready)
    .s_axis_tdata(udp_axis_tdata),
    .s_axis_tkeep(udp_axis_tkeep),
    .s_axis_tvalid(udp_axis_tvalid),
    .s_axis_tlast(udp_axis_tlast),
    /* verilator lint_off PINCONNECTEMPTY */
    .s_axis_tready(),   
    /* verilator lint_on PINCONNECTEMPTY*/
    .ip4cs(ip4cs),        
    .ip4cs_vld(ip4cs_vld),
    .udpcs(udpcs),               
    .udpcs_vld(udpcs_vld) // valid on tlast+1 cycle
);


gate_pkt_buffer#(
    .AXIS_WIDTH(S_AXIS_WIDTH),
    .ADDR_WIDTH(CSGATE_ADDR_WIDTH)
) cs_gater(
    .clk(axis_aclk),
    .aresetn(axis_aresetn),

    .dbg_rxmode(dbg_rxmode),
    .udpcs(udpcs),
    .udpcs_vld(udpcs_vld),
    .ip4cs(ip4cs),
    .ip4cs_vld(ip4cs_vld),
    /** Status signals**/
    .memory_gap(gate_mm_gap), // the gap between the read and write queue
    .discard_cnt(csfailed_cnt), // count how manytime the memory is discarded.

    /** Input Streams **/
    .s00_axis_tdata(udp_axis_tdata),
    .s00_axis_tkeep(udp_axis_tkeep),
    .s00_axis_tlast(udp_axis_tlast),
    .s00_axis_tvalid(udp_axis_tvalid),
    /* verilator lint_off PINCONNECTEMPTY */
    .s00_axis_tready(),
    /* verilator lint_on PINCONNECTEMPTY*/
    /** Output Streams **/
    .m00_axis_tdata(csgate_axis_tdata),
    .m00_axis_tkeep(csgate_axis_tkeep),
    .m00_axis_tlast(csgate_axis_tlast),
    .m00_axis_tvalid(csgate_axis_tvalid),

    /* verilator lint_off PINCONNECTEMPTY */
    .m00_axis_tready()
    /* verilator lint_on PINCONNECTEMPTY*/
);

assign ip4cs_stat = {ip4cs_vld, ip4cs};
assign udpcs_stat = {udpcs_vld, udpcs};
// no back pressure
assign s00_axis_tready = 1;

localparam LOGGER_AWIDTH = 10;

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

// === status registers for pulse signals
logic [2*BYTES-1:0]         arp_vld_cnt;
logic [2*BYTES-1:0]         udp_vld_cnt;
logic [2*BYTES-1:0]         ip4cs_nPass;
logic [2*BYTES-1:0]         ip4cs_logger;
logic [2*BYTES-1:0]         udpcs_nPass;
logic [2*BYTES-1:0]         udpcs_logger;

// data logging
always_ff @(posedge axis_aclk) begin
    if(!axis_aresetn) begin
        arp_vld_cnt    <=0;
        udp_vld_cnt    <=0;
        ip4cs_logger   <=0;
        ip4cs_nPass    <=0;
        udpcs_nPass    <=0;
    end else begin
        if(s00_axis_tlast) begin
            if(demux_type == 2) arp_vld_cnt <= arp_vld_cnt + 1;
            if(demux_type == 1) udp_vld_cnt <= udp_vld_cnt + 1;
        end
        // once the valid is high => log the output
        if(ip4cs_stat[16]) begin
            ip4cs_logger <= ip4cs_stat[15:0];
            if(ip4cs_stat[15:0] == 16'hFFFF) ip4cs_nPass <= ip4cs_nPass + 1;
        end 
        if(udpcs_stat[16]) begin
            udpcs_logger <= udpcs_stat[15:0];
            if(udpcs_stat[15:0] == 16'h0000) udpcs_nPass <= udpcs_nPass + 1;
        end
    end
end


prober#(.A_WIDTH(LOGGER_AWIDTH),
        .D_WIDTH(M_AXIS_WIDTH))
data_logger(
    .aclk(axis_aclk),
    .aresetn(axis_aresetn),
    .sw_clear(logger_clear),
    .udp_axis_tlast(udp_axis_tlast),
    .udp_axis_tvalid(udp_axis_tvalid),
    .wr_en((demux_type==1)&&s00_axis_tvalid),
    .wr_din(s00_axis_tdata),
    .rd_addr(logger_rAddr),
    .rd_dout(logger_rDout),
    .gap_cnt(gap_between_pkts),
    .gap_cnt_vld(gap_pkts_vld)
);

assign masked_wr_addr = reg_wr_addr & 32'h0000FFFF;
assign masked_rd_addr = reg_rd_addr & 32'h0000FFFF;

// AXI Lite Read: read from some rtl regs
always_comb begin
    case(masked_rd_addr)
        // 0-100: This is for configuration registers
        32'h0:  begin reg_rd_data = {24'h0, dbg_rxmode}; reg_rd_ack = 1'b1; end
        32'h4:  begin reg_rd_data = {16'd0, eth_exp.cmac_mac[15:0]}; reg_rd_ack = 1'b1; end
        32'h8:  begin reg_rd_data = {16'd0, eth_exp.cmac_mac[31:16]}; reg_rd_ack = 1'b1; end
        32'hC:  begin reg_rd_data = {16'd0, eth_exp.cmac_mac[47:32]}; reg_rd_ack = 1'b1; end
        32'h10: begin reg_rd_data = {16'd0, eth_exp.nic_mac[15:0]}; reg_rd_ack = 1'b1; end
        32'h14: begin reg_rd_data = {16'd0, eth_exp.nic_mac[31:16]}; reg_rd_ack = 1'b1; end
        32'h18: begin reg_rd_data = {16'd0, eth_exp.nic_mac[47:32]}; reg_rd_ack = 1'b1; end
        32'h1C: begin reg_rd_data = {16'd0, eth_exp.mac_type}; reg_rd_ack = 1'b1; end
        32'h20: begin reg_rd_data = {24'd0, ip4_exp.ip_version}; reg_rd_ack = 1'b1; end
        32'h24: begin reg_rd_data = {16'd0, ip4_exp.payload_length}; reg_rd_ack = 1'b1; end
        32'h28: begin reg_rd_data = {16'd0, ip4_exp.checksum}; reg_rd_ack = 1'b1; end
        32'h2C: begin reg_rd_data = ip4_exp.cmac_ip; reg_rd_ack = 1'b1; end
        32'h30: begin reg_rd_data = ip4_exp.nic_ip; reg_rd_ack = 1'b1; end
        32'h34: begin reg_rd_data = {16'd0, udp_exp.cmac_port}; reg_rd_ack = 1'b1; end
        32'h38: begin reg_rd_data = {16'd0, udp_exp.nic_port}; reg_rd_ack = 1'b1; end
        32'h3C: begin reg_rd_data = {16'd0, udp_exp.udp_checksum}; reg_rd_ack = 1'b1; end
        32'h40: begin reg_rd_data = {16'd0, udp_exp.udp_length}; reg_rd_ack = 1'b1; end
        // 200 - forward: This is for status registers
        32'h200: begin reg_rd_data = {16'h0, udp_vld_cnt}; reg_rd_ack = 1'b1; end
        32'h204: begin reg_rd_data = {16'h0, arp_vld_cnt}; reg_rd_ack = 1'b1; end
        32'h208: begin reg_rd_data = {16'h0, ip4cs_logger}; reg_rd_ack = 1'b1; end
        32'h20C: begin reg_rd_data = {16'h0, ip4cs_nPass}; reg_rd_ack = 1'b1; end
        32'h210: begin reg_rd_data = {16'h0, udpcs_logger}; reg_rd_ack = 1'b1; end
        32'h214: begin reg_rd_data = {16'h0, udpcs_nPass}; reg_rd_ack = 1'b1; end
        32'h218: begin reg_rd_data = {24'h0, gate_mm_gap}; reg_rd_ack = 1'b1; end
        32'h21C: begin reg_rd_data = {16'h0, csfailed_cnt}; reg_rd_ack = 1'b1; end
        32'h220: begin reg_rd_data = gap_between_pkts;      reg_rd_ack = gap_pkts_vld; end
        // 300 - captured header info
        32'h304: begin reg_rd_data = {16'd0, eth_cap.cmac_mac[15:0]}; reg_rd_ack = 1'b1; end
        32'h308: begin reg_rd_data = {16'd0, eth_cap.cmac_mac[31:16]}; reg_rd_ack = 1'b1; end
        32'h30C: begin reg_rd_data = {16'd0, eth_cap.cmac_mac[47:32]}; reg_rd_ack = 1'b1; end
        32'h310: begin reg_rd_data = {16'd0, eth_cap.nic_mac[15:0]}; reg_rd_ack = 1'b1; end
        32'h314: begin reg_rd_data = {16'd0, eth_cap.nic_mac[31:16]}; reg_rd_ack = 1'b1; end
        32'h318: begin reg_rd_data = {16'd0, eth_cap.nic_mac[47:32]}; reg_rd_ack = 1'b1; end
        32'h31C: begin reg_rd_data = {16'd0, eth_cap.mac_type}; reg_rd_ack = 1'b1; end
        32'h320: begin reg_rd_data = {24'd0, ip4_cap.ip_version}; reg_rd_ack = 1'b1; end
        32'h324: begin reg_rd_data = {16'd0, ip4_cap.payload_length}; reg_rd_ack = 1'b1; end
        32'h328: begin reg_rd_data = {16'd0, ip4_cap.checksum}; reg_rd_ack = 1'b1; end
        32'h32C: begin reg_rd_data = ip4_cap.cmac_ip; reg_rd_ack = 1'b1; end
        32'h330: begin reg_rd_data = ip4_cap.nic_ip; reg_rd_ack = 1'b1; end
        32'h334: begin reg_rd_data = {16'd0, udp_cap.cmac_port}; reg_rd_ack = 1'b1; end
        32'h338: begin reg_rd_data = {16'd0, udp_cap.nic_port}; reg_rd_ack = 1'b1; end
        32'h33C: begin reg_rd_data = {16'd0, udp_cap.udp_checksum}; reg_rd_ack = 1'b1; end
        32'h340: begin reg_rd_data = {16'd0, udp_cap.udp_length}; reg_rd_ack = 1'b1; end
        // 400 - the loggers
        32'h400: begin reg_rd_data = {31'h0, logger_clear}; reg_rd_ack = 1'b1; end
        32'h404: begin reg_rd_data = {22'h0, logger_rAddr}; reg_rd_ack = 1'b1; end
        default: begin reg_rd_data = 32'hDEADBEEF; reg_rd_ack = 1'b0; end
    endcase
    // 100-200: This is for writing all configuration
    if (masked_rd_addr >= 32'h100 && masked_rd_addr < 32'h164) begin // reg_rd_addr jumps 4 each
        reg_rd_data = custom_arp_reg[(masked_rd_addr-32'h100)*8 +: 32];
        reg_rd_ack = 1'b1;
    end
    if (masked_rd_addr >= 32'h408 && masked_rd_addr < 32'h448) begin // reg_rd_addr jumps 4 each, each has 32-bit
        reg_rd_data = logger_rDout[(masked_rd_addr-32'h408)*8 +: 32];
        reg_rd_ack = 1'b1;
    end
end

always_ff @(posedge axil_aclk) begin
    if (!axil_aresetn) begin
        // reset defaults here
        custom_arp_reg <= '0;
        dbg_rxmode     <= 8'h0;
        eth_exp        <= '0;
        ip4_exp        <= '0;
        udp_exp        <= '0;
    end else begin 
        if (reg_wr_en) begin
            case(masked_wr_addr)
                32'h0:  begin dbg_rxmode <= reg_wr_data[7:0]; end
                32'h4:  begin eth_exp.cmac_mac[15:0] <= reg_wr_data[15:0]; end
                32'h8:  begin eth_exp.cmac_mac[31:16] <= reg_wr_data[15:0]; end
                32'hC:  begin eth_exp.cmac_mac[47:32] <= reg_wr_data[15:0]; end
                32'h10: begin eth_exp.nic_mac[15:0] <= reg_wr_data[15:0]; end
                32'h14: begin eth_exp.nic_mac[31:16] <= reg_wr_data[15:0]; end
                32'h18: begin eth_exp.nic_mac[47:32] <= reg_wr_data[15:0]; end
                32'h1C: begin eth_exp.mac_type <= reg_wr_data[15:0]; end
                32'h20: begin ip4_exp.ip_version <= reg_wr_data[7:0]; end
                32'h24: begin ip4_exp.payload_length <= reg_wr_data[15:0]; end
                32'h28: begin ip4_exp.checksum <= reg_wr_data[15:0]; end
                32'h2C: begin ip4_exp.cmac_ip <= reg_wr_data[31:0]; end
                32'h30: begin ip4_exp.nic_ip <= reg_wr_data[31:0]; end
                32'h34: begin udp_exp.cmac_port <= reg_wr_data[15:0]; end
                32'h38: begin udp_exp.nic_port <= reg_wr_data[15:0]; end
                32'h3C: begin udp_exp.udp_checksum <= reg_wr_data[15:0]; end
                32'h40: begin udp_exp.udp_length <= reg_wr_data[15:0]; end
                // default: Do nothing 
                //400-500: for the logger
                32'h400: begin logger_clear <= reg_wr_data[0]; end
                32'h404: begin logger_rAddr <= reg_wr_data[LOGGER_AWIDTH-1:0]; end
            endcase
            if (masked_wr_addr >= 32'h100 && masked_wr_addr < 32'h164) begin // reg_wr_addr jumps 4 each
                custom_arp_reg[(masked_wr_addr-32'h100)*8 +: 32] <= reg_wr_data;
            end
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
// cdc for axil_registers
cdc_axil_regs x_cdc_inst(
    .axis_aclk(axis_aclk),
    .axis_aresetn(axis_aresetn),
    .axil_aclk(axil_aclk),
    .axil_aresetn(axil_aresetn),

    .dbg_mode(dbg_rxmode),
    .eth_exp(eth_exp),
    .ip4_exp(ip4_exp),
    .udp_exp(udp_exp),

    .dbg_mode_sync(dbg_rxmode_sync),
    .eth_exp_sync(eth_exp_sync),
    .ip4_exp_sync(ip4_exp_sync),
    .udp_exp_sync(udp_exp_sync)
);

// no backpressure

assign s00_axis_tready = 1;
endmodule

