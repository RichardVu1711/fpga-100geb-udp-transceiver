module prober#(
    parameter A_WIDTH = 10,
    parameter D_WIDTH = 512
) (
    input  logic               aclk,
    input  logic               aresetn,
    input  logic               sw_clear,
    input  logic               wr_en,
    input  logic               udp_axis_tlast,
    input  logic               udp_axis_tvalid,

    input  logic [D_WIDTH-1:0] wr_din,
    input  logic [A_WIDTH-1:0] rd_addr,
    output logic [D_WIDTH-1:0] rd_dout,

    output logic [31:0]        gap_cnt,
    output logic               gap_cnt_vld
);
localparam MSIZE = 1<<A_WIDTH;

logic [D_WIDTH-1: 0] mem [MSIZE];
logic [A_WIDTH-1: 0] wr_cnt;

logic [31:0] max_cnt;
logic [31:0] cnt;
logic        pkt_active;

assign gap_cnt = max_cnt;

always_ff @(posedge aclk) begin
    if(!aresetn) begin
        cnt     <= 0;
        max_cnt <= 0;
    end else begin
        gap_cnt_vld <= 0;
        if(udp_axis_tvalid) begin
            if(udp_axis_tlast) begin
                if(!pkt_active) begin
                    pkt_active <= 1;
                    cnt        <= 0;
                    if(cnt > max_cnt) begin
                        max_cnt     <= cnt;
                        gap_cnt_vld <= 1;
                    end
                end
            end else begin
                // the valid packet is coming => stop counting
                pkt_active <= 0;
            end 
        end
        if(pkt_active) begin
            cnt <= cnt + 1;
        end
    end
end


always @(posedge aclk) begin
    if(!aresetn || sw_clear) begin
        wr_cnt <= 0;
    end else begin
        if(wr_en) wr_cnt <= wr_cnt + 1;
        mem[wr_cnt] <= wr_din;
    end
end

always @(posedge aclk) begin
    if(!aresetn || sw_clear) begin
        rd_dout <= {480'h0,32'hdeadbeef};
    end else begin
        rd_dout <= mem[rd_addr];
    end
end

endmodule
