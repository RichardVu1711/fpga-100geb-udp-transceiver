module axis_ff#(
    parameter AXIS_WIDTH = 512
)(
    input  logic clk,
    input  logic aresetn,

    input  logic [AXIS_WIDTH-1:0]     s_axis_tdata,
    input  logic [(AXIS_WIDTH/8)-1:0] s_axis_tkeep,
    input  logic                      s_axis_tvalid,
    input  logic                      s_axis_tready,   // sampled, not driven
    input  logic                      s_axis_tlast,

    output logic [AXIS_WIDTH-1:0]     m_axis_tdata,
    output logic [(AXIS_WIDTH/8)-1:0] m_axis_tkeep,
    output logic                      m_axis_tvalid,
    output logic                      m_axis_tready,   // sampled, not driven
    output logic                      m_axis_tlast
);

            
// sampled, not driven
    
always_ff @(posedge clk) begin
    if(!aresetn) begin
        m_axis_tdata  <= 0;
        m_axis_tkeep  <= 0;
        m_axis_tvalid <= 0;
        m_axis_tready <= 0;  
        m_axis_tlast  <= 0;
    end else begin
        m_axis_tdata  <= s_axis_tdata;
        m_axis_tkeep  <= s_axis_tkeep;
        m_axis_tvalid <= s_axis_tvalid;
        m_axis_tready <= s_axis_tready;  
        m_axis_tlast  <= s_axis_tlast;
    end
end


endmodule

