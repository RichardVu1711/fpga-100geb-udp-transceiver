module ip4cs_core 
import my_type::*;
#(
    parameter IP4_LEN = 20
)(
    input  logic                     aclk,
    input  logic                     aresetn,
    input  logic [IP4_LEN*BYTES-1:0] ip4_hdr,
    input  logic                     ip4_hdr_vld,
    output logic [15:0]              ip4cs,    // checksum value
    output logic                     ip4cs_vld // if checksum result is ready.

);

localparam WORD = 16;

logic [WORD-1:0] w[10];
logic [25:0]     s0;       // sum at layer 0
logic [25:0]     s0_pipe;  // pipeline at layer
logic [16:0]     s4;       // sum at layer 4
logic [15:0]     sOut;     // sum at layer 5
logic [1:0]      vld_pipe;



// Pipeline unit
always_ff @(posedge aclk) begin
    if(!aresetn) begin
        s0_pipe  <= 0;
        vld_pipe <= 0;
    end else begin
        s0_pipe  <= s0;
        // ip4_hdr is loaded at ip4_hdr_vld, this will be delayed for 2 cycle
        vld_pipe <= {vld_pipe[0], ip4_hdr_vld};
    end
end

genvar i;
generate
    for(i=0; i < 10; i=i+1) begin
        assign w[i] = ip4_hdr[(i)*WORD +: WORD];
    end
endgenerate

//         w0 w1 w2 ... w9   (16b each, zero-extended to 26b)
//         └──────┬──────┘
//                +                 10-input add
//              s0[25:0]
// — — — — — — — — — — — — — —     pipeline reg  →  s1
// s0_pipe[25:16]   s0_pipe[15:0]
//                +          fold 1
//        s4[16]      s4[15:0]
//                +          fold 2
//             sOut[15:0]

assign s0 = {10'h0, w[0]} + {10'h0, w[1]} +
            {10'h0, w[2]} + {10'h0, w[3]} +
            {10'h0, w[4]} + {10'h0, w[5]} +
            {10'h0, w[6]} + {10'h0, w[7]} +
            {10'h0, w[8]} + {10'h0, w[9]}; 

assign s4        = {1'h0, s0_pipe[15:0]} + {6'h0, s0_pipe[25:16]};
assign sOut      = s4[15:0]              + s4[16];
assign ip4cs_vld = vld_pipe[0];
assign ip4cs     = sOut;

endmodule

