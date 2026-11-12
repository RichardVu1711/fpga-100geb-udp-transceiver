module create_tx_udp 
import my_type::*;
#(
    parameter AXIS_WIDTH=512
)(
    input logic    aclk,
    input logic    aresetn,
    /** Configure Registers**/
    input  udp_tx_t                     hdr_info,
    /*
     * AXI Stream interface, come from the DMA
     */
     input  logic [AXIS_WIDTH-1 : 0]     s00_axis_tdata,
     input  logic [(AXIS_WIDTH/8)-1 : 0] s00_axis_tkeep,
     input  logic                        s00_axis_tlast,
     input  logic                        s00_axis_tvalid,
     output logic                        s00_axis_tready,

    /** Output Checksum **/
    output logic                        hdr_vld,
    output hdrtx_cal_t                  calhdr_info
);

function logic [12*BYTES-1:0] crt_pseudoheader(udp_tx_t hdr_in);
    crt_pseudoheader[4*BYTES-1:0]         = hdr_in.cmac_ip; // source IP -- the sender IP -- CMAC
    crt_pseudoheader[8*BYTES-1:4*BYTES]   = hdr_in.nic_ip;  // dest IP -- the receiver IP -- NIC
    crt_pseudoheader[9*BYTES-1:8*BYTES]   = 0; 
    crt_pseudoheader[10*BYTES-1:9*BYTES]  = hdr_in.time_proto[15:8];  // proto => expected = 17;
    crt_pseudoheader[12*BYTES-1:10*BYTES] = hdr_in.udp_len; //    
endfunction

function logic [8*BYTES-1:0] crt_udpheader(udp_tx_t hdr_in);
    crt_udpheader[2*BYTES-1:0]       = hdr_in.udp_checksum;
    crt_udpheader[4*BYTES-1:2*BYTES] = hdr_in.udp_len;
    crt_udpheader[6*BYTES-1:4*BYTES] = hdr_in.nic_port;  //Destination Port -- NIC
    crt_udpheader[8*BYTES-1:6*BYTES] = hdr_in.cmac_port;  //Source Port -- NIC
endfunction

localparam IP4_LEN = 20; // in Bytes
localparam IP4_S   = 8;  // I put the UDP header at the end of LSB of the struct => IP4 start after UDP header (8)
localparam IP4_E   = 28;
localparam WORD    = 16;
localparam QSIZE = 16;
localparam QADDR = $clog2(QSIZE);
// IP4 Len should be written via the axi4 lite, before packet is sending.
logic [IP4_LEN*BYTES-1:0] ip4_hdr;
logic                     pkt_vld;
logic                     pkt_active;
logic [WORD-1:0]          ip4cs;
logic                     ip4cs_vld;
logic [WORD-1:0]          udpcs;
logic                     udpcs_vld;
// UDP-related header
logic [AXIS_WIDTH-1 : 0] axis_filtered;
logic [12*BYTES-1:0]     pseudo_header;
logic [8*BYTES-1:0]      udp_header;
logic                    udp_hdr_vld;

// // latching ip4cs_vld and udpcs_vld
// logic                    ip4cs_latch;
// logic                    udpcs_latch;



// Calculate the udp, ip, len, and checksums.
logic [15:0]      ip4cs_log[QSIZE];
logic [15:0]      udpcs_log[QSIZE];
logic [QADDR-1:0] wr_ip4_qptr, wr_udp_qptr, rd_qptr;

always_ff @(posedge aclk) begin
    if(!aresetn) begin
        wr_ip4_qptr <= 0; wr_udp_qptr <= 0; rd_qptr <= 0; hdr_vld <= 0;
    end else begin
        if(ip4cs_vld) begin
            ip4cs_log[wr_ip4_qptr] <= ip4cs;
            wr_ip4_qptr            <= wr_ip4_qptr + 1;
        end
        if(udpcs_vld) begin
            udpcs_log[wr_udp_qptr] <= udpcs;
            wr_udp_qptr            <= wr_udp_qptr + 1;
        end

        if(rd_qptr != wr_ip4_qptr && rd_qptr != wr_udp_qptr) begin
            calhdr_info.ip4_checksum <= ip4cs_log[rd_qptr];
            calhdr_info.udp_checksum <= udpcs_log[rd_qptr];
            hdr_vld                 <= 1;
            rd_qptr                 <= rd_qptr + 1;
        end else begin
            hdr_vld <= 0;
        end
    end
end

// Extract the ip4 header information from the configured register
always_ff @(posedge aclk) begin
    if(!aresetn) begin
        pkt_vld    <= 0;
        pkt_active     <= 0;
        pseudo_header  <= 0;
        udp_header     <= 0;
    end else begin
        if(s00_axis_tvalid && !pkt_active) begin
            pkt_active    <= 1;
            pkt_vld       <= 1;
            pseudo_header <= crt_pseudoheader(hdr_info);
            udp_header    <= crt_udpheader(hdr_info);
        end else begin
            pkt_vld    <= 0;
            if(s00_axis_tlast) begin
                pkt_active <= 0;
            end
        end
    end
end

assign ip4_hdr = hdr_info[IP4_E*BYTES-1:IP4_S*BYTES];

// ip4 checksum compute
ip4cs_core #(.IP4_LEN(IP4_LEN))
ip4cs_core_inst(
    .aclk(aclk),
    .aresetn(aresetn),
    .ip4_hdr(ip4_hdr),
    .ip4_hdr_vld(pkt_vld),
    .ip4cs(ip4cs),
    .ip4cs_vld(ip4cs_vld)
);

// udp checksum compute
genvar k;
generate
    for (k =0; k < AXIS_WIDTH/8; k = k +1) begin
        assign axis_filtered[k*BYTES+: BYTES] = s00_axis_tdata[k*BYTES+7:k*BYTES] &
                                                {BYTES{s00_axis_tkeep[k]}}; 
    end
endgenerate

udpcs_core #(
    .HDR_INLINE(0),
    .AXIS_WIDTH(AXIS_WIDTH)
) udpcs_core_inst(
    .aclk(aclk),
    .aresetn(aresetn),

    .axis_filtered(axis_filtered),
    .pipe_axis_tvalid(s00_axis_tvalid),
    .pipe_axis_tlast(s00_axis_tlast),

    .pseudo_header(pseudo_header),
    .udp_header(udp_header),
    .udp_hdr_vld(pkt_vld),
    .checksum(udpcs),               // valid on tlast+1 cycle
    .checksum_valid(udpcs_vld)
);
endmodule

