module TXTop_wrapper
#(
    // AXIL parameters: data + address width
    parameter AXIL_DWIDTH  = 32,
    parameter AXIL_AWIDTH  = 32,
    // AXIStream bus: data width
    parameter S_AXIS_WIDTH = 512,
    parameter M_AXIS_WIDTH = 512

)
(
`ifndef VERILATOR
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axil_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axil, ASSOCIATED_RESET axil_aresetn, FREQ_HZ 100000000" *)
`endif
    input  wire                          axil_aclk,
    input  wire                          axil_aresetn,
`ifndef VERILATOR
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axis_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s00_axis:m00_axis:sarp_axis, ASSOCIATED_RESET axis_aresetn, FREQ_HZ 300000000" *)
`endif
    input  wire                           axis_aclk,
    input  wire                           axis_aresetn,
    /*
     * AXI Stream interface, comes from the DMA
     */
    output wire  s00_axis_tready,
    input  wire [S_AXIS_WIDTH-1 : 0    ] s00_axis_tdata,
    input  wire [(S_AXIS_WIDTH/8)-1 : 0] s00_axis_tkeep,
    input  wire  s00_axis_tlast,
    input  wire  s00_axis_tvalid,
    
    /*
     * AXI Stream interface
     */
    output wire  sarp_axis_tready,
    input  wire [S_AXIS_WIDTH-1 : 0    ] sarp_axis_tdata,
    input  wire [(S_AXIS_WIDTH/8)-1 : 0] sarp_axis_tkeep,
    input  wire  sarp_axis_tlast,
    input  wire  sarp_axis_tvalid,

    /** Output Streams **/
    output wire [M_AXIS_WIDTH-1 : 0]     m00_axis_tdata,
    output wire [(M_AXIS_WIDTH/8)-1 : 0] m00_axis_tkeep,
    output wire                          m00_axis_tlast,
    output wire                          m00_axis_tvalid,
    input  wire                          m00_axis_tready,

    /*
     * AXI-Lite slave interface
     */
    input  wire  [AXIL_AWIDTH-1:0]        s_axil_awaddr,
    input  wire  [2:0]                    s_axil_awprot,
    input  wire                           s_axil_awvalid,
    output wire                           s_axil_awready,
    input  wire  [AXIL_DWIDTH-1:0]        s_axil_wdata,
    input  wire  [(AXIL_DWIDTH)/8-1:0]    s_axil_wstrb,
    input  wire                           s_axil_wvalid,
    output wire                           s_axil_wready,
    output wire  [1:0]                    s_axil_bresp,
    output wire                           s_axil_bvalid,
    input  wire                           s_axil_bready,
    input  wire  [AXIL_AWIDTH-1:0]        s_axil_araddr,
    input  wire  [2:0]                    s_axil_arprot,
    input  wire                           s_axil_arvalid,
    output wire                           s_axil_arready,
    output wire  [AXIL_DWIDTH-1:0]        s_axil_rdata,
    output wire  [1:0]                    s_axil_rresp,
    output wire                           s_axil_rvalid,
    input  wire                           s_axil_rready         
);

TXTop#(
    .AXIL_DWIDTH(AXIL_DWIDTH), 
    .AXIL_AWIDTH(AXIL_AWIDTH),
    .S_AXIS_WIDTH(S_AXIS_WIDTH),
    .M_AXIS_WIDTH(M_AXIS_WIDTH)
) TXTop_inst(
    .axil_aclk(axil_aclk),
    .axil_aresetn(axil_aresetn),
    .axis_aclk(axis_aclk),
    .axis_aresetn(axis_aresetn),
    /*
     * AXI Stream interface, comes from the DMA
     */
    .s00_axis_tready(s00_axis_tready),
    .s00_axis_tdata(s00_axis_tdata),
    .s00_axis_tkeep(s00_axis_tkeep),
    .s00_axis_tlast(s00_axis_tlast),
    .s00_axis_tvalid(s00_axis_tvalid),
    
    /*
     * AXI Stream interface
     */
    .sarp_axis_tready(sarp_axis_tready),
    .sarp_axis_tdata(sarp_axis_tdata),
    .sarp_axis_tkeep(sarp_axis_tkeep),
    .sarp_axis_tlast(sarp_axis_tlast),
    .sarp_axis_tvalid(sarp_axis_tvalid),

    /** Output Streams **/
    .m00_axis_tdata(m00_axis_tdata),
    .m00_axis_tkeep(m00_axis_tkeep),
    .m00_axis_tlast(m00_axis_tlast),
    .m00_axis_tvalid(m00_axis_tvalid),
    .m00_axis_tready(m00_axis_tready),

    /*
     * AXI-Lite slave interface
     */
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

