module gate_tx_buffer
import my_type::*;
#(
    parameter AXIS_WIDTH = 512,
    parameter ADDR_WIDTH = 8
)(
    input  logic aclk,
    input  logic aresetn,
    /** Header Info **/
    input  udp_tx_t                     hdr_info,
    input  hdrtx_cal_t                  calhdr_info,
    
    /** Flag signals**/
    input  logic [7:0]                  dbg_txmode,
    input  logic                        rd_en,
    /** Input Streams **/
    input  logic [AXIS_WIDTH-1 : 0]     s00_axis_tdata,
    input  logic [(AXIS_WIDTH/8)-1 : 0] s00_axis_tkeep,
    input  logic                        s00_axis_tlast,
    input  logic                        s00_axis_tvalid,
    output logic                        s00_axis_tready,
    /** Output Streams **/
    output logic [AXIS_WIDTH-1 : 0]     m00_axis_tdata,
    output logic [(AXIS_WIDTH/8)-1 : 0] m00_axis_tkeep,
    output logic                        m00_axis_tlast,
    output logic                        m00_axis_tvalid,
    input  logic                        m00_axis_tready
);

localparam BSIZE = 1<< ADDR_WIDTH;
localparam QSIZE = 16;             // the delay between upstream and downstream
localparam QADDR = $clog2(QSIZE);
logic [AXIS_WIDTH-1:0] buffer_mem [BSIZE];

logic [ADDR_WIDTH-1:0] wr_ptr;
logic [ADDR_WIDTH-1:0] wr_cnt;
logic [ADDR_WIDTH-1:0] rd_ptr;
logic [ADDR_WIDTH-1:0] rd_cnt;

logic [AXIS_WIDTH-1 : 0]     gate_axis_tdata;
logic [(AXIS_WIDTH/8)-1 : 0] gate_axis_tkeep;
logic                        gate_axis_tlast;
logic                        gate_axis_tvalid;
logic                        gate_axis_tready;

// Keep recording data from s00_axis (DMA)
logic [ADDR_WIDTH-1:0] q_wr_s_addr[QSIZE];
logic [ADDR_WIDTH-1:0] q_wr_cnt [QSIZE];
logic [335:0]          q_wr_hdr[QSIZE];
logic [335:0]          hdr_wires;
logic [QADDR-1:0]      wr_hdr_qptr;
logic [QADDR-1:0]      q_wr_ptr;
logic [QADDR-1:0]      q_rd_ptr;
logic [1:0]            rd_stt; // 2 mean reading, 1 mean header first, and 0 mean idle

assign hdr_wires = {hdr_info.nic_mac,        // [335:288]
                    hdr_info.cmac_mac,       // [287:240]
                    hdr_info.mac_type,       // [239:224]
                    hdr_info.ip_version,     // [223:216]
                    hdr_info.dscp_ecn,       // [215:208]
                    hdr_info.ip4_len,        // [207:192]
                    hdr_info.identity,       // [191:176]
                    hdr_info.flag_frag,      // [175:160]
                    hdr_info.time_proto,     // [159:144]
                    calhdr_info.ip4_checksum,// [143:128]  <- from calhdr_info
                    hdr_info.cmac_ip,        // [127:96]
                    hdr_info.nic_ip,         // [95:64]
                    hdr_info.cmac_port,      // [63:48]
                    hdr_info.nic_port,       // [47:32]
                    hdr_info.udp_len,        // [31:16]
                    calhdr_info.udp_checksum // [15:0]   <- from calhdr_info
                    };

always_ff @(posedge aclk) begin
    if(!aresetn) begin
        wr_hdr_qptr <= 0;
    end else if(rd_en) begin
        q_wr_hdr[wr_hdr_qptr] <= hdr_wires;
        wr_hdr_qptr           <= wr_hdr_qptr + 1;
    end
end

// Read_enable signal come => realse the whole set dataset
always_ff @(posedge aclk) begin
    if(!aresetn) begin
        wr_ptr         <= 0;
        wr_cnt         <= 0;
        q_wr_ptr       <= 0;
        q_wr_s_addr[0] <= 0;
    end else begin
        if(s00_axis_tvalid) begin
            buffer_mem[wr_ptr] <= s00_axis_tdata;
            wr_ptr             <= wr_ptr + 1;
            wr_cnt             <= wr_cnt + 1;
            if(s00_axis_tlast) begin
                q_wr_s_addr[q_wr_ptr+1] <= wr_ptr;
                q_wr_cnt[q_wr_ptr]      <= wr_cnt;
                wr_cnt                  <= 0; // reset for the next
                q_wr_ptr                <= q_wr_ptr + 1;
            end
        end
    end
end


// Read FSM:
always_ff @(posedge aclk) begin
    if(!aresetn) begin
        rd_stt  <= 0;
    end else begin
        case(rd_stt)
        0: begin if(q_rd_ptr != wr_hdr_qptr) rd_stt <= 1; end
        1: begin rd_stt <= 2; end
        2: begin if(rd_ptr == q_wr_cnt[q_rd_ptr]) rd_stt <= 0; end
        endcase
    end
end

// Read until end of packet
// The read MUST BE conducted with an re allignedment, where the header need to be attached
// or the write MUST restructure the memory padded header first, then what ever the memory
always_ff @(posedge aclk) begin
    if(!aresetn) begin
        rd_ptr         <= 0;
        rd_cnt         <= 0;
        q_rd_ptr       <= 0;
    end else begin
        if(rd_stt == 2) begin
            if(q_rd_ptr < q_wr_ptr) begin
                if(rd_ptr <= q_wr_cnt[q_rd_ptr]) begin
                    gate_axis_tdata  <= buffer_mem[q_wr_s_addr[q_rd_ptr]+rd_ptr];
                    gate_axis_tkeep  <= {AXIS_WIDTH/8{1'h1}};
                    gate_axis_tvalid <= 1;
                    if(rd_ptr == q_wr_cnt[q_rd_ptr]) begin
                        gate_axis_tlast <= 1;
                        rd_ptr          <= 0;
                        q_rd_ptr        <= q_rd_ptr + 1;
                    end else begin
                        gate_axis_tlast <= 0;
                        rd_ptr <= rd_ptr + 1;
                    end
                end else begin
                    // It couldn't be this case
                    $fatal(1, "Error: rd_ptr cannot greater than q_wr_cnt[q_rd_ptr].");
                    gate_axis_tdata[31:0] <= 32'hdeadbeef;
                end
            end else begin
                gate_axis_tdata  <= 0;
                gate_axis_tvalid <= 0;
                gate_axis_tkeep  <= 0;
                gate_axis_tlast  <= 0;
            end
        end else if (rd_stt == 1) begin
            gate_axis_tdata  <= {{176{1'b1}}, q_wr_hdr[q_rd_ptr]};
            gate_axis_tvalid <= 1;
            gate_axis_tkeep  <= {{22{1'b0}},{42{1'b1}}};
            gate_axis_tlast  <= 0;
        end else begin
            gate_axis_tdata  <= 0;
            gate_axis_tvalid <= 0;
            gate_axis_tkeep  <= 0;
            gate_axis_tlast  <= 0;
        end
    end
end


// No back pressure
assign s00_axis_tready = 1;
assign gate_axis_tready = m00_axis_tready;

// debug info
always_comb begin
    if(dbg_txmode == 8'h20) begin
        m00_axis_tdata  = s00_axis_tdata;
        m00_axis_tkeep  = s00_axis_tkeep;
        m00_axis_tlast  = s00_axis_tlast;
        m00_axis_tvalid = s00_axis_tvalid;
    end else begin // dbg_txmode == 0
        m00_axis_tdata  = gate_axis_tdata;
        m00_axis_tkeep  = gate_axis_tkeep;
        m00_axis_tlast  = gate_axis_tlast;
        m00_axis_tvalid = gate_axis_tvalid;
    end
end
endmodule

