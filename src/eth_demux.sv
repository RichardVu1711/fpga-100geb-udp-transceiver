
module eth_demux
import my_type::*;
#(
    parameter S_AXIS_WIDTH = 512,
    parameter M_AXIS_WIDTH = 512
)(
    input clk,
    input aresetn,

    /** Configuration parameters **/
    input eth_t                           eth_exp,
    input ip4_t                           ip4_exp,
    input udp_t                           udp_exp,
    input logic [7:0]                     dbg_rxmode,
    input logic [M_AXIS_WIDTH-1:0]        custom_arp_reg,
    /** Status parameters **/
    output logic [1:0]                    demux_type,
    output eth_t                          eth_cap,
    output ip4_t                          ip4_cap,
    output udp_t                          udp_cap,
    /** In/Out stream **/ 
    input  logic [S_AXIS_WIDTH-1 : 0    ] s00_axis_tdata,
    input  logic [(S_AXIS_WIDTH/8)-1 : 0] s00_axis_tkeep,
    input  logic                          s00_axis_tlast,
    input  logic                          s00_axis_tvalid,
    output logic                          s00_axis_tready,

    output logic [M_AXIS_WIDTH-1 : 0    ] mudp_axis_tdata,
    output logic [(M_AXIS_WIDTH/8)-1 : 0] mudp_axis_tkeep,
    input  logic                          mudp_axis_tready,
    output logic                          mudp_axis_tlast,
    output logic                          mudp_axis_tvalid,
    
    output logic [M_AXIS_WIDTH-1 : 0    ] marp_axis_tdata,
    output logic [(M_AXIS_WIDTH/8)-1 : 0] marp_axis_tkeep,
    input  logic                          marp_axis_tready,
    output logic                          marp_axis_tlast,
    output logic                          marp_axis_tvalid
);

logic [M_AXIS_WIDTH-1 : 0    ] udp_axis_tdata;
logic [(M_AXIS_WIDTH/8)-1 : 0] udp_axis_tkeep;
logic                          udp_axis_tready;
logic                          udp_axis_tlast;
logic                          udp_axis_tvalid;
logic                          udp_valid;
logic                          udp_transfer;

logic [M_AXIS_WIDTH-1 : 0    ] arp_axis_tdata;
logic [(M_AXIS_WIDTH/8)-1 : 0] arp_axis_tkeep;
logic                          arp_axis_tready;
logic                          arp_axis_tlast;
logic                          arp_axis_tvalid;
logic                          arp_valid;
logic                          arp_transfer;

// captured signal
/* verilator lint_off UNUSEDPARAM */
arp_tx_t arp_reply;
// ====== Construct Arp Reply =====
assign arp_reply.nic_mac  = eth_exp.nic_mac;
assign arp_reply.cmac_mac = eth_exp.cmac_mac;
assign arp_reply.mac_type = 16'h0608; // Ethertype (ARP): 0x0806 - byte reversed to 0x0608
assign arp_reply.hw_type  = 16'h0100; // Hardware Type (Ethernet): 0x0001 - byte reversed to 0x0100
assign arp_reply.proto_type = 16'h0008; // Protocol Type (IPv4): 0x0800 - byte reversed to 0x0008
assign arp_reply.hw_len = 8'h06; // HW Length: 6 bytes for MAC layer
assign arp_reply.proto_len = 8'h04; // proto Length: 4 bytes for IPv4 Layer
assign arp_reply.op_code = 16'h0200; // Op Code (ARP Reply): 0x0002 - byte reversed to 0x0200
assign arp_reply.sender_mac = eth_exp.cmac_mac; // send from cmac to nic
assign arp_reply.sender_ip = ip4_exp.cmac_ip;
assign arp_reply.target_mac = eth_exp.nic_mac; // send from cmac to nic
assign arp_reply.target_ip = ip4_exp.nic_ip; 
// ===== Finite State Machine ====
localparam idle= 0;
localparam passing_udp =1;
localparam passing_arp =2;

logic [1:0] states;
logic cmac_mac_ok, nic_mac_ok;
logic cmac_ip_ok, nic_ip_ok;
logic cmac_port_ok, nic_port_ok;
logic ipv4_ok, proto_ok;

assign eth_cap.cmac_mac   = slice_cmacMac(s00_axis_tdata);
assign eth_cap.nic_mac    = slice_nicMac(s00_axis_tdata);
assign eth_cap.mac_type   = slice_ethType(s00_axis_tdata);
assign ip4_cap.nic_ip     = slice_nicIP(s00_axis_tdata);
assign ip4_cap.cmac_ip    = slice_cmacIP(s00_axis_tdata);
assign ip4_cap.ip_version = slice_ipv4(s00_axis_tdata);
assign ip4_cap.proto      = slice_proto(s00_axis_tdata);

assign cmac_mac_ok = (eth_cap.cmac_mac   == eth_exp.cmac_mac);
assign nic_mac_ok  = (eth_cap.nic_mac    == eth_exp.nic_mac);
assign cmac_ip_ok  = (ip4_cap.cmac_ip    == ip4_exp.cmac_ip);
assign nic_ip_ok   = (ip4_cap.nic_ip     == ip4_exp.nic_ip);
assign proto_ok    = (ip4_cap.proto      == 8'h11); //shouldn't hard code this, but who cares
assign ipv4_ok     = (ip4_cap.ip_version == ip4_exp.ip_version);
assign udp_valid   = (eth_cap.mac_type == 16'h0008) &&   // 0008 is the reversed of eth_type (IPv4) = 0x0800
                    cmac_mac_ok && nic_mac_ok && cmac_ip_ok && 
                    nic_ip_ok && proto_ok;
assign arp_valid   = (eth_cap.mac_type == 16'h0608) &&  // 0608 is the reversed of eth_type (ARP) = 0x0806
                    ((eth_cap.cmac_mac == {48{1'h1}}) || (cmac_mac_ok)) 
                    && nic_mac_ok;

// TODO: I need to clean up this later                    
logic                    arp_reply_pending;
logic [M_AXIS_WIDTH-1:0] arp_reply_latched;
logic [3:0]              tmp_cnt;

always_ff @(posedge clk) begin
    if (!aresetn) begin
        arp_reply_pending <= 1'b0;
        tmp_cnt           <= 4'h0;
    end else begin
        if (arp_valid && !arp_reply_pending) begin
            arp_reply_latched <= {176'h0, arp_reply};
            arp_reply_pending <= 1'b1;
            tmp_cnt           <= 0;
        end else if (arp_reply_pending) begin
            tmp_cnt <= tmp_cnt + 1;
            if(tmp_cnt == 1)  arp_reply_pending <= 1'b0;  // transfer completed, clear
        end
    end
end

// Mode 1x: test mode for eth_demux
//      10: pass the input directly to the output
//      11: pass the custom_arp_reg to the output
always_comb begin
    if(dbg_rxmode == 8'h10) begin
        mudp_axis_tdata  = s00_axis_tdata;
        mudp_axis_tkeep  = s00_axis_tkeep;
        mudp_axis_tvalid = s00_axis_tvalid;
        mudp_axis_tlast  = s00_axis_tlast;
        marp_axis_tdata  = s00_axis_tdata;
        marp_axis_tkeep  = s00_axis_tkeep;
        marp_axis_tvalid = s00_axis_tvalid;
        marp_axis_tlast  = s00_axis_tlast;
        demux_type       = 0;
    end else if (dbg_rxmode == 8'h11) begin
        mudp_axis_tdata  = custom_arp_reg;
        mudp_axis_tkeep  = {64{1'h1}};
        mudp_axis_tvalid = 1;
        mudp_axis_tlast  = 1;
        marp_axis_tdata  = custom_arp_reg;
        marp_axis_tkeep  = {64{1'h1}};
        marp_axis_tvalid = 1;
        marp_axis_tlast  = 1;
        demux_type       = 0;
    end else begin
        if(udp_valid || (states == passing_udp) ) begin
            mudp_axis_tdata  = s00_axis_tdata;
            mudp_axis_tkeep  = s00_axis_tkeep;
            mudp_axis_tvalid = (s00_axis_tvalid);
            mudp_axis_tlast  = s00_axis_tlast;
            marp_axis_tdata  = 0;
            marp_axis_tkeep  = 0;
            marp_axis_tvalid = 0;
            marp_axis_tlast  = 0;
            demux_type       = 1;
        end else if (udp_valid || (states == passing_arp)) begin
            mudp_axis_tdata  =  0;
            mudp_axis_tkeep  =  0;
            mudp_axis_tvalid =  0;
            mudp_axis_tlast  =  0;

            marp_axis_tdata  = arp_reply_latched;
            marp_axis_tkeep  = {M_AXIS_WIDTH/8{1'h1}};
            marp_axis_tvalid = 1;
            marp_axis_tlast  = 1;
            demux_type       = 2;
        end else begin
            mudp_axis_tdata  = 0;
            mudp_axis_tkeep  = 0;
            mudp_axis_tvalid = 0;
            mudp_axis_tlast  = 0;
            marp_axis_tdata  = 0;
            marp_axis_tkeep  = 0;
            marp_axis_tvalid = 0;
            marp_axis_tlast  = 0;
            demux_type       = 0;
        end
    end
end

always_ff @(posedge clk) begin
    if (!aresetn) begin
    end else begin
        case(states) 
        idle: begin
            if(udp_valid) states <= passing_udp;
            else if(arp_valid) states <= passing_arp;
        end
        passing_udp: begin
            if(s00_axis_tlast) begin
                states <= idle;
            end
        end 
        passing_arp: begin
            if(s00_axis_tlast) begin
                states <= idle;
            end
        end
        default: states <=idle;
        endcase
    end
end

assign s00_axis_tready = 1;


endmodule
