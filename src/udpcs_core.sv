module udpcs_core 
import my_type::*;
#(
    /* verilator lint_off UNUSEDPARAM */
    parameter HDR_INLINE = 1,  // 1 = header lives in-band in axis_filtered (RX), 0 = pure payload (TX)
    /* verilator lint_on */
    parameter AXIS_WIDTH = 512
)(
    input  logic                  aclk,
    input  logic                  aresetn,

    input  logic [AXIS_WIDTH-1:0] axis_filtered,
    input  logic                  pipe_axis_tvalid,
    input  logic                  pipe_axis_tlast,

    input  logic [12*BYTES-1:0]   pseudo_header,
    input  logic [8*BYTES-1:0]    udp_header,
    input  logic                  udp_hdr_vld,

    output logic [15:0]           checksum,        // valid on tlast+1 cycle
    output logic                  checksum_valid   // indicate is the checksum is being computed.
);
/* verilator lint_off UNUSEDPARAM */
localparam idle = 0 ;
localparam first_pkt = 1;
localparam middle_pkt = 2;
localparam end_pkt = 3;
/* verilator lint_on UNUSEDPARAM */
logic [2:0] fsm_state;
logic       isContinuous;

logic [25:0]           cs_all;    // Assume that I will receive extra 10 beat of 512 bit axis
logic [16:0]           cs_all_fold;
logic [15:0]           csp_header;
logic [15:0]           csu_header;
logic [15:0]           cs_payloadH;
logic [15:0]           cs_payloadL;

logic                  csp_hdr_vld;
logic                  csu_hdr_vld;
logic                  cs_plH_vld;
logic                  cs_plL_vld;
logic                  cs_all_vld;

logic [AXIS_WIDTH-1:0] payload;
logic                  payload_vld;
logic                  payload_last;
logic                  finalise;

// assign cs_all_fold    = {1'h0,cs_all[15:0]} + {6'h0,cs_all[25:16]};
// assign checksum       = ~(cs_all_fold[15:0] + {15'h0,cs_all_fold[16]});
// assign checksum_valid = cs_all_vld;

assign payload_vld    = pipe_axis_tvalid;
assign payload_last   = pipe_axis_tlast;
assign payload        = axis_filtered;

logic hdr_latch;
logic pl_latch;
logic tlast_latch;
// UDP checksum covers a "pseudo-header" + UDP header + data:

// UDP Checksum datapath:
// stream in =====> psuedo Header + UDP Header => onecader (pseudo_header) + onecadder(udp_header)
//                  payload                    => onecadder(payload[511:256])
//                                             => onecadder(payload[255:0])
// Pseudo-header:
// +---------------+---------------+
// | Source IP (4) | Dest IP (4)   |
// +---------------+---------------+----------------+
// | Zero (1)      | Proto (1)=17  | UDP Length (2) |
// +---------------+---------------+----------------+
// UDP header:
// +---------------+---------------+
// | Src Port (2)  | Dst Port (2)  |
// +---------------+---------------+
// | Length (2)    | Checksum (2)  |
// +---------------+---------------+

always_ff @(posedge aclk) begin
    if(!aresetn) begin
        cs_all   <= 0;
    end else begin
        if(finalise) begin
            /* verilator lint_off BLKSEQ */
            cs_all_fold    = {1'h0,cs_all[15:0]} + {6'h0,cs_all[25:16]};
            checksum       = ~(cs_all_fold[15:0] + {15'h0,cs_all_fold[16]});
            /* verilator lint_on */
            checksum_valid <= 1;
            cs_all <= (csp_hdr_vld ? {10'h0, csp_header} : 0)  +  // normal accumulate
                      (csu_hdr_vld ? {10'h0, csu_header} : 0)  +
                      (cs_plH_vld  ? {10'h0, cs_payloadH} : 0) +
                      (cs_plL_vld  ? {10'h0, cs_payloadL} : 0);
                
        end else begin
            cs_all <= cs_all +  (csp_hdr_vld ? {10'h0, csp_header} : 0)  +  // normal accumulate
                                (csu_hdr_vld ? {10'h0, csu_header} : 0)  +
                                (cs_plH_vld  ? {10'h0, cs_payloadH} : 0) +
                                (cs_plL_vld  ? {10'h0, cs_payloadL} : 0);
            checksum_valid <= 0;
            checksum       <= 16'hbeef;
        end
    end
end
//  This is a recording, once all data is collected => raise the condition, and reset it
always_ff @(posedge aclk) begin
    if(!aresetn) begin
        finalise    <= 0;
        hdr_latch   <= 0;
        pl_latch    <= 0;
        tlast_latch <= 0;
    end else begin
        // as the the csp and csu valid at the same clock, so just needs to just one to latch
        if(csu_hdr_vld) begin
            hdr_latch <= 1;
            if(tlast_latch && (pl_latch || cs_plH_vld)) begin
                finalise <= 1;
            end 
        end
        if(cs_plH_vld) begin
            pl_latch <= 1;
            if(tlast_latch && (csu_hdr_vld || hdr_latch)) begin
                finalise <= 1;
            end
        end
        // tlast is latched until the computation results are valid (~2clk cycle after its arrival)
        if(payload_last) begin
            tlast_latch <= 1;
        end
        if(finalise) begin
            // There is a case that the payload is finalised but the payload_header is calculated.
            if(csu_hdr_vld) hdr_latch <= 1;
            else            hdr_latch <= 0;
            if(cs_plH_vld)  pl_latch  <= 1;
            else            pl_latch  <= 0;

            tlast_latch <= 0;
            finalise    <= 0;
        end
    end
end
onec_adder#(
    .NBYTES(12)
) onec_12B(
    .clk(aclk),
    .aresetn(aresetn),

    .str_in(pseudo_header),
    .str_vld(udp_hdr_vld),
    .onec_sum(csp_header),
    .onec_vld(csp_hdr_vld)
);

onec_adder#(
    .NBYTES(8)
) onec_8B(
    .clk(aclk),
    .aresetn(aresetn),

    .str_in(udp_header),
    .str_vld(udp_hdr_vld),
    .onec_sum(csu_header),
    .onec_vld(csu_hdr_vld)
);

// Followed by UDP data.

onec_adder#(
    .NBYTES(32)
) onec_32B_H (
    .clk(aclk),
    .aresetn(aresetn),

    .str_in(payload[511:256]),
    .str_vld(payload_vld),
    .onec_sum(cs_payloadH),
    .onec_vld(cs_plH_vld)
);

onec_adder#(
    .NBYTES(32)
) onec_32B_L (
    .clk(aclk),
    .aresetn(aresetn),

    .str_in(payload[255:0]),
    .str_vld(payload_vld),
    .onec_sum(cs_payloadL),
    .onec_vld(cs_plL_vld)
);

endmodule


