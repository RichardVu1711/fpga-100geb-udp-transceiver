module onec_adder
import my_type::*;
#(
    parameter NBYTES = 64
)(
    input  logic                    clk,
    input  logic                    aresetn,

    input  logic [NBYTES*BYTES-1:0] str_in,
    input  logic                    str_vld,
    output logic [2*BYTES-1:0]      onec_sum,
    output logic                    onec_vld
);
localparam NWORDS = NBYTES/2 ;
localparam WORDS  = 16;
localparam EXTLEN =$clog2(NWORDS);
logic [15:0]                  w[NWORDS];
logic [(15+EXTLEN):0] s0;       // sum at layer 0
logic [(15+EXTLEN):0] s0_pipe;  // pipeline after the accumulator
logic [(15+1):0]      s1;
logic [(15):0]        sOut;
logic [1:0]           vld_pipe;

genvar k;
generate
    for(k=0; k < NWORDS;k = k +1) begin
        assign w[k] = str_in[(k+1)*WORDS-1:k*WORDS];
    end
endgenerate

always_comb begin : intermediate_adder
    s0  = 0;
    for(int i =0; i < NWORDS;i++) begin
        s0 = s0 + {{EXTLEN{1'h0}}, w[i]};
    end
end

always_ff @( posedge clk ) begin : pipe_0
    if(!aresetn) begin
        s0_pipe  <= 0;
        vld_pipe <=0;
    end else begin
        s0_pipe  <= s0;
        vld_pipe <= {vld_pipe[0],str_vld};
    end
end

assign s1       = {1'h0,s0_pipe[15:0]} + {{(16-EXTLEN){1'h0}},s0_pipe[(15+EXTLEN):16]};
assign sOut     = s1[15:0] + s1[16];
assign onec_sum = sOut;
assign onec_vld = vld_pipe[0];

endmodule

