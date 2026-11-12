`timescale 1 ps / 1 ps

module RXTop_wrapper
#(
    // Width of data bus in bits
    parameter AXIL_DWIDTH  = 32,
    // Width of address bus in bits
    parameter AXIL_AWIDTH  = 32,
    parameter S_AXIS_WIDTH = 512,
    parameter M_AXIS_WIDTH = 512
)(
`ifndef VERILATOR
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axil_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axil, ASSOCIATED_RESET axil_aresetn, FREQ_HZ 100000000" *)
`endif
    input  wire                          axil_aclk,
    input  wire                          axil_aresetn,
`ifndef VERILATOR
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s00_axis:m00_axis:marp_axis, ASSOCIATED_RESET axis_aresetn, FREQ_HZ 300000000" *)
`endif
    input  wire                          axis_aclk,
    input  wire                          axis_aresetn,
    /** Status Register **/
    output wire [7:0]                    debug_prob,
    output wire [1:0]                    demux_type,

    /** Input Streams **/
    input  wire [S_AXIS_WIDTH-1 : 0 ]    s00_axis_tdata,
    input  wire [(S_AXIS_WIDTH/8)-1 : 0] s00_axis_tkeep,
    input  wire                          s00_axis_tlast,
    input  wire                          s00_axis_tvalid,
    output wire                          s00_axis_tready,
    /** Output Streams **/
    output wire [M_AXIS_WIDTH-1 : 0]     marp_axis_tdata,
    output wire [(M_AXIS_WIDTH/8)-1 : 0] marp_axis_tkeep,
    output wire                          marp_axis_tlast,
    output wire                          marp_axis_tvalid,
    input  wire                          marp_axis_tready,

    output wire [M_AXIS_WIDTH-1 : 0]     m00_axis_tdata,
    output wire [(M_AXIS_WIDTH/8)-1 : 0] m00_axis_tkeep,
    output wire                          m00_axis_tlast,
    input  wire                          m00_axis_tready,
    output wire                          m00_axis_tvalid,

    /** AXI-Lite slave interface **/
    input  wire  [AXIL_AWIDTH-1:0]       s_axil_awaddr,
    input  wire  [2:0]                   s_axil_awprot,
    input  wire                          s_axil_awvalid,
    output wire                          s_axil_awready,
    input  wire  [AXIL_DWIDTH-1:0]       s_axil_wdata,
    input  wire  [(AXIL_DWIDTH)/8-1:0]   s_axil_wstrb,
    input  wire                          s_axil_wvalid,
    output wire                          s_axil_wready,
    output wire  [1:0]                   s_axil_bresp,
    output wire                          s_axil_bvalid,
    input  wire                          s_axil_bready,
    input  wire  [AXIL_AWIDTH-1:0]       s_axil_araddr,
    input  wire  [2:0]                   s_axil_arprot,
    input  wire                          s_axil_arvalid,
    output wire                          s_axil_arready,
    output wire  [AXIL_DWIDTH-1:0]       s_axil_rdata,
    output wire  [1:0]                   s_axil_rresp,
    output wire                          s_axil_rvalid,
    input  wire                          s_axil_rready             
);
RXTop #(
    .AXIL_DWIDTH(AXIL_DWIDTH), 
    .AXIL_AWIDTH(AXIL_AWIDTH),
    .S_AXIS_WIDTH(S_AXIS_WIDTH),
    .M_AXIS_WIDTH(M_AXIS_WIDTH)
) rxtop_inst (
    .axil_aclk(axil_aclk),
    .axil_aresetn(axil_aresetn),
    .axis_aclk(axis_aclk),
    .axis_aresetn(axis_aresetn),
    /** Status Registers **/
    .debug_prob(debug_prob),
    .demux_type(demux_type),

    /** Input Streams **/
    .s00_axis_tdata(s00_axis_tdata),
    .s00_axis_tkeep(s00_axis_tkeep),
    .s00_axis_tlast(s00_axis_tlast),
    .s00_axis_tvalid(s00_axis_tvalid),
    .s00_axis_tready(s00_axis_tready),
    /** Output Streams **/
    .m00_axis_tdata(m00_axis_tdata),
    .m00_axis_tkeep(m00_axis_tkeep),
    .m00_axis_tlast(m00_axis_tlast),
    .m00_axis_tvalid(m00_axis_tvalid),
    .m00_axis_tready(m00_axis_tready),

    .marp_axis_tdata(marp_axis_tdata),
    .marp_axis_tkeep(marp_axis_tkeep),
    .marp_axis_tlast(marp_axis_tlast),
    .marp_axis_tvalid(marp_axis_tvalid),
    .marp_axis_tready(marp_axis_tready),

    /** AXI-Lite slave interface **/
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
    .s_axil_rready(s_axil_rready)     
);



endmodule

