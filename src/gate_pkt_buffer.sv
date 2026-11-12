module gate_pkt_buffer
import my_type::*;
#(
    parameter AXIS_WIDTH = 512,
    parameter ADDR_WIDTH = 16
)(
    input  logic clk,
    input  logic aresetn,

    /** Flag signals**/
    input  logic [7:0]                  dbg_rxmode,
    input  logic [2*BYTES-1:0]          udpcs,
    input  logic                        udpcs_vld,
    input  logic [2*BYTES-1:0]          ip4cs,
    input  logic                        ip4cs_vld,
    /** Status signals**/
    output logic [ADDR_WIDTH-1:0]       memory_gap, // the gap between the read and write queue
    output logic [16-1:0]               discard_cnt, // count how manytime the memory is discarded.

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
localparam QSIZE = 16;   // the delay between upstream and downstream
localparam QADDR = $clog2(QSIZE);

logic [AXIS_WIDTH-1:0] buffer_mem [BSIZE];
logic [AXIS_WIDTH-1:0] s00_axis_masked;
logic [ADDR_WIDTH-1:0] ptr_wr_active;

logic [ADDR_WIDTH-1:0] wr_cnt;
logic                  wr_recorded;
logic                  wr_ack_sync;
logic [ADDR_WIDTH-1:0] ptr_rd_active;


// when the packet arrives and ends
logic [ADDR_WIDTH-1:0] q_wr_ptr_start[QSIZE];
logic [ADDR_WIDTH-1:0] q_wr_cnt[QSIZE];
logic [15:0]           ip4_log [QSIZE];
logic [15:0]           udp_log [QSIZE];

logic [QADDR-1:0]      wr_wr_qptr;
logic [QADDR-1:0]      wr_ip4_qptr;
logic [QADDR-1:0]      wr_udp_qptr;

logic [QADDR-1:0]      rd_qptr;
logic [ADDR_WIDTH-1:0] rd_ptr;
logic                  ready_to_rd;


logic [AXIS_WIDTH-1 : 0]     csgate_axis_tdata;
logic [(AXIS_WIDTH/8)-1 : 0] csgate_axis_tkeep;
logic                        csgate_axis_tlast;
logic                        csgate_axis_tvalid;
logic                        csgate_axis_tready;

logic [(ADDR_WIDTH-4)-1 : 0] padd_m4;
assign padd_m4 = {(ADDR_WIDTH-4){1'h0}};
// ======== TEST/DEBUG MODE ========
// Mode 2x: test mode for csgate_buffer
//      20: pass the input directly to the output
always_comb begin
    if(dbg_rxmode == 8'h20) begin
        m00_axis_tdata  = s00_axis_tdata;
        m00_axis_tkeep  = s00_axis_tkeep;
        m00_axis_tlast  = s00_axis_tlast;
        m00_axis_tvalid = s00_axis_tvalid;
    end else begin
        m00_axis_tdata  = csgate_axis_tdata;
        m00_axis_tkeep  = csgate_axis_tkeep;
        m00_axis_tlast  = csgate_axis_tlast;
        m00_axis_tvalid = csgate_axis_tvalid;
    end
end

genvar k;
generate
    for(k=0; k < (AXIS_WIDTH/8); k=k+1)
        assign s00_axis_masked[(k+1)*BYTES-1:k*BYTES] = s00_axis_tdata[(k+1)*BYTES-1:k*BYTES]
                                                        & {BYTES{s00_axis_tkeep[k]}}; 
endgenerate

// The idea is that, I will write as fast as possible to buffer_mem.
// the start and pkt_len will be logged into a queue (a ring fifo)
// The read will based on the checksum to decide whether to discard or transmit the data within the buffer

// recording the checksum at ip4 and udp
always_ff @(posedge clk) begin
    if(!aresetn) begin
        ip4_log <= '{default: '0};
        udp_log <= '{default: '0};
        wr_ip4_qptr <= 0;
        wr_udp_qptr <= 0;
    end else begin
        if(ip4cs_vld) begin
            ip4_log[wr_ip4_qptr] <= ip4cs;
            wr_ip4_qptr       <= wr_ip4_qptr + 1;
        end
        if(udpcs_vld) begin
            // update the write queue once the udp checksum is vald
            udp_log[wr_udp_qptr] <= udpcs;
            wr_udp_qptr          <= wr_udp_qptr + 1;
        end
    end
end
// ============= Write ====================== 
always_ff @(posedge clk) begin  
    if(!aresetn) begin
        ptr_wr_active     <= 0;
        wr_cnt            <= 0;
        wr_wr_qptr        <= 0;
        q_wr_ptr_start[0] <= 0; // the queue will always to log 0;
    end else begin
        if(s00_axis_tvalid) begin
            buffer_mem[ptr_wr_active] <= s00_axis_masked;
            ptr_wr_active             <= ptr_wr_active + 1;
            wr_cnt                    <= wr_cnt + 1;
            if(s00_axis_tlast) begin
                q_wr_ptr_start[wr_wr_qptr+1] <= ptr_wr_active + 1; // store the previous value of tmp
                q_wr_cnt[wr_wr_qptr]         <= wr_cnt;
                wr_wr_qptr                   <= wr_wr_qptr + 1;
                wr_cnt                       <= 0;
            end
        end
    end
end

// ============= Read =====================
always_ff @(posedge clk) begin  
    if(!aresetn) begin
        rd_qptr         <= 0;
        rd_ptr          <= 0;
        csgate_axis_tdata  <= 0;
        csgate_axis_tvalid <= 0;
        csgate_axis_tkeep  <= 0;
        csgate_axis_tlast  <= 0;
        discard_cnt     <= 0;
    end else begin 
        // start the read as long there is a stall between up/down stream
        if( rd_qptr != wr_udp_qptr) begin
            if(udp_log[rd_qptr] == ~(16'hffff) && ip4_log[rd_qptr]  == 16'hffff) begin
                csgate_axis_tdata  <= buffer_mem[q_wr_ptr_start[rd_qptr]+rd_ptr];
                csgate_axis_tkeep  <= {AXIS_WIDTH/8{1'h1}};
                csgate_axis_tvalid <= 1;
                if(q_wr_cnt[rd_qptr] == rd_ptr) begin
                    // Finish reading
                    csgate_axis_tlast  <= 1;
                    rd_ptr             <= 0;
                    rd_qptr            <= rd_qptr +1;
                end else begin
                    csgate_axis_tlast  <= 0;
                    rd_ptr             <= rd_ptr + 1;
                end
            end else begin
                // Corrupt packets => ignore this packet
                rd_qptr            <= rd_qptr + 1;
                rd_ptr             <= 0;
                csgate_axis_tdata  <= {480'h0, {32'hDEDABEEF}};
                csgate_axis_tkeep  <= 0;
                csgate_axis_tvalid <= 0;
                csgate_axis_tlast  <= 0;
                discard_cnt        <= discard_cnt + 1;
            end
        end else begin
            csgate_axis_tdata  <= 0;
            csgate_axis_tkeep  <= 0;
            csgate_axis_tvalid <= 0;
            csgate_axis_tlast  <= 0;
        end
    end
end

always_ff @(posedge clk) begin
    if(!aresetn) begin
        memory_gap <= 0;
    end else begin 
        if({padd_m4,wr_udp_qptr - rd_qptr} >  memory_gap) begin
            memory_gap <= {padd_m4,wr_udp_qptr - rd_qptr};
        end
    end
end 

assign s00_axis_tready = 1;

endmodule

