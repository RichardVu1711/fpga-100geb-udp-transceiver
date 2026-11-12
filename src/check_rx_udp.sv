module check_rx_udp 
import my_type::*;
#(
    parameter AXIS_WIDTH = 512
) (
    input  logic                       aclk,
    input  logic                       aresetn,

    // streaming input (tap off the real data path, doesn't gate tready)
    input  logic [AXIS_WIDTH-1:0]      s_axis_tdata,
    input  logic [(AXIS_WIDTH/8)-1:0]  s_axis_tkeep,
    input  logic                       s_axis_tvalid,
    input  logic                       s_axis_tready,   // sampled, not driven
    input  logic                       s_axis_tlast,

    output logic [15:0]                ip4cs,     // checksum value
    output logic                       ip4cs_vld, // if checksum result is ready.
    output logic [15:0]                udpcs,     // valid on tlast+1 cycle
    output logic                       udpcs_vld  // indicate is the checksum is being computed.
);

logic [AXIS_WIDTH-1:0]     pipe_axis_tdata;
logic [(AXIS_WIDTH/8)-1:0] pipe_axis_tkeep;
logic                      pipe_axis_tvalid;
logic                      pipe_axis_tlast;
logic                      pipe_axis_tready;
logic [AXIS_WIDTH-1:0]     axis_filtered;

// Pipeline incoming stream to break the critical path
axis_ff#(
    .AXIS_WIDTH(AXIS_WIDTH)
) axis_pipe(
    .clk(aclk),
    .aresetn(aresetn),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    /* verilator lint_off PINCONNECTEMPTY*/
    .s_axis_tready(),   // sampled, not driven
    /* verilator lint_on PINCONNECTEMPTY*/

    .m_axis_tdata(pipe_axis_tdata),
    .m_axis_tkeep(pipe_axis_tkeep),
    .m_axis_tvalid(pipe_axis_tvalid),
    .m_axis_tready(pipe_axis_tready),   // sampled, not driven
    .m_axis_tlast(pipe_axis_tlast)
);
// Extraction Functionn

function logic [12*BYTES-1:0] slice_pseudoheader(logic [511:0] str_in);
    slice_pseudoheader[4*BYTES-1:0]         = slice_nicIP(str_in);   // source IP -- the sender IP -- NIC
    slice_pseudoheader[8*BYTES-1:4*BYTES]   = slice_cmacIP(str_in);  // dest IP -- the receiver IP -- CMAC
    slice_pseudoheader[9*BYTES-1:8*BYTES]   = 0; 
    slice_pseudoheader[10*BYTES-1:9*BYTES]  = slice_proto(str_in);  // proto => expected = 17;
    slice_pseudoheader[12*BYTES-1:10*BYTES] = slice_udpLen(str_in); //    
endfunction

function logic [8*BYTES-1:0] slice_udpheader(logic [511:0] str_in);
    slice_udpheader[8*BYTES-1:0] = str_in[42*BYTES-1:34*BYTES];
endfunction

// Constant param
localparam IP4_LEN = 20; // in Bytes
localparam IP4_S   = 14;
localparam IP4_E   = 34;
// localparam WORD    = 16;

// extracted ip4 
logic [IP4_LEN*BYTES-1:0] ip4_hdr;
logic                     ip4_hdr_vld;
logic                     ip4_pkt_active;

logic [12*BYTES-1:0]      pseudo_header;
logic [8*BYTES-1:0]       udp_header;
logic                     udp_hdr_vld;
logic                     udp_pkt_active;

logic [AXIS_WIDTH-1:0]    payload_only;
logic                     payload_vld;
logic                     payload_last;



// Filter tkeep data
genvar k;
generate
    for(k =0; k < AXIS_WIDTH/8;k = k+1) begin
        assign axis_filtered[k*BYTES+: BYTES] = pipe_axis_tdata[k*BYTES+7:k*BYTES] &
                                                {BYTES{pipe_axis_tkeep[k]}};
    end
endgenerate

// assign payload_only = (!udp_pkt_active) ? {336'h0, axis_filtered[64*BYTES-1:42*BYTES]} :
//                                         axis_filtered;

// Extract data for ipcs_core
always_ff @(posedge aclk) begin
    if(!aresetn) begin
        ip4_hdr        <= 0;
        ip4_hdr_vld    <= 0;
        ip4_pkt_active <= 0;
    end else begin
        if(pipe_axis_tvalid && ip4_pkt_active == 0) begin
            ip4_hdr        <= pipe_axis_tdata[IP4_E*BYTES - 1: IP4_S*BYTES];
            ip4_hdr_vld    <= 1;
            ip4_pkt_active <= 1;
        end else begin
            ip4_hdr_vld <= 0;
            if(pipe_axis_tlast) begin
                ip4_pkt_active <= 0;
            end
        end
    end
end
// feed data into ip4cs_core
ip4cs_core#(
    .IP4_LEN(IP4_LEN)
) ip4cs_core_inst(
    .aclk(aclk),
    .aresetn(aresetn),

    .ip4_hdr(ip4_hdr),
    .ip4_hdr_vld(ip4_hdr_vld),
    .ip4cs(ip4cs),        // checksum value
    .ip4cs_vld(ip4cs_vld) // if checksum result is ready.
);

// Extract the data for udpcs_core
// Will merge this latter, keep it to ensure the functionality of udpcs_core
always_ff @(posedge aclk) begin
    if(!aresetn) begin
        pseudo_header  <= 0;
        udp_header     <= 0;
        udp_hdr_vld    <= 0;
        udp_pkt_active <= 0;
    end else begin
        if(pipe_axis_tvalid && !udp_pkt_active) begin
            pseudo_header  <= slice_pseudoheader(axis_filtered);
            udp_header     <= slice_udpheader(axis_filtered);
            udp_hdr_vld    <= 1;
            udp_pkt_active <= 1;
            payload_only   <= {336'h0, axis_filtered[64*BYTES-1:42*BYTES]};
        end  else begin
            udp_hdr_vld  <= 0;
            payload_only <= axis_filtered;
            if(pipe_axis_tlast) udp_pkt_active <= 0;
        end
        payload_vld  <= pipe_axis_tvalid;
        payload_last <= pipe_axis_tlast;
    end
end

udpcs_core#(
    .AXIS_WIDTH(AXIS_WIDTH),
    .HDR_INLINE(0)
) udpcs_core_inst (
    .aclk(aclk),
    .aresetn(aresetn),

    .axis_filtered(payload_only),
    .pipe_axis_tvalid(payload_vld),
    .pipe_axis_tlast(payload_last),
    .pseudo_header(pseudo_header),
    .udp_header(udp_header),
    .udp_hdr_vld(udp_hdr_vld),
    .checksum(udpcs),               // valid on tlast+1 cycle
    .checksum_valid(udpcs_vld)
);

endmodule

