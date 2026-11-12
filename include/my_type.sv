package my_type;
    localparam UDP_WIDTH = 16;
    localparam IP4_WIDTH = 32;
    localparam ETH_WIDTH = 48;
    localparam BYTES            = 8;
    localparam CMAC_WIDTH       = 512;

    /** RX COMPONENTS**/
    typedef struct packed {
        logic [ETH_WIDTH-1:0] nic_mac;
        logic [ETH_WIDTH-1:0] cmac_mac;
        logic [15:0] mac_type;
    } eth_t;


    typedef struct packed {
        logic [7:0]           ip_version;
        logic [15:0]          payload_length;
        logic [7:0]           proto;
        logic [15:0]          checksum;
        logic [IP4_WIDTH-1:0] nic_ip;
        logic [IP4_WIDTH-1:0] cmac_ip;
    } ip4_t;

    typedef struct packed {
        logic [UDP_WIDTH-1:0] nic_port;
        logic [UDP_WIDTH-1:0] cmac_port;
        logic [15:0] udp_length;
        logic [15:0] udp_checksum;
    } udp_t;

    /** TX COMPONENTS **/
    typedef struct packed {
        logic [31:0]          target_ip;
        logic [47:0]          target_mac;
        logic [31:0]          sender_ip;
        logic [47:0]          sender_mac;
        logic [15:0]          op_code;
        logic [7:0]           proto_len;
        logic [7:0]           hw_len;
        logic [15:0]          proto_type;
        logic [15:0]          hw_type;
        logic [15:0]          mac_type;
        logic [ETH_WIDTH-1:0] cmac_mac;
        logic [ETH_WIDTH-1:0] nic_mac;  // --->LSB first byte to send
    } arp_tx_t;

    typedef struct packed {
        // Start of MAC
        logic [ETH_WIDTH-1:0] nic_mac; // ---> MSB
        logic [ETH_WIDTH-1:0] cmac_mac;
        logic [15:0]          mac_type; 
        // Start of IP4
        logic [7:0]           ip_version;
        logic [7:0]           dscp_ecn;
        logic [15:0]          ip4_len;
        logic [15:0]          identity;
        logic [15:0]          flag_frag;
        logic [15:0]          time_proto;
        logic [15:0]          ip4_checksum;
        logic [31:0]          cmac_ip;
        logic [31:0]          nic_ip;
        // Start of UDP
        logic [15:0]          cmac_port; 
        logic [15:0]          nic_port;
        logic [15:0]          udp_len;
        logic [15:0]          udp_checksum; // ---> LSB
    } udp_tx_t;

    typedef struct packed {
        logic [15:0]          ip4_len;
        logic [15:0]          ip4_checksum;
        logic [15:0]          udp_len;
        logic [15:0]          udp_checksum;
    } hdrtx_cal_t;


    function logic[2*BYTES-1:0] byteswap16(logic[2*BYTES-1:0] byteIn);
        byteswap16 = {byteIn[1*BYTES-1:0*BYTES],
                      byteIn[2*BYTES-1:1*BYTES]};    
    endfunction
    // These function is named to extract the cmac stream in (what comes out of cmac RX port)
    function logic[6*BYTES-1:0] slice_cmacMac(logic[CMAC_WIDTH-1:0] cmac_rx);
        slice_cmacMac = cmac_rx[6*BYTES-1:0*BYTES];
    endfunction

    function logic[6*BYTES-1:0] slice_nicMac(logic[CMAC_WIDTH-1:0] cmac_rx);
        slice_nicMac = cmac_rx[12*BYTES-1:6*BYTES];
    endfunction

    function logic[2*BYTES-1:0] slice_ethType(logic[CMAC_WIDTH-1:0] cmac_rx);
        slice_ethType = cmac_rx[14*BYTES-1:12*BYTES];
    endfunction

    function logic[7:0] slice_ipv4(logic[CMAC_WIDTH-1:0] cmac_rx);
        slice_ipv4 = cmac_rx[15*BYTES-1:14*BYTES];
    endfunction
    
    function logic[1*BYTES-1:0] slice_proto(logic[CMAC_WIDTH-1:0] cmac_rx);
        slice_proto = cmac_rx[24*BYTES-1:23*BYTES];
    endfunction

    function logic[4*BYTES-1:0] slice_nicIP(logic[CMAC_WIDTH-1:0] cmac_rx);
        slice_nicIP = cmac_rx[30*BYTES-1:26*BYTES];
    endfunction

    function logic[4*BYTES-1:0] slice_cmacIP(logic[CMAC_WIDTH-1:0] cmac_rx);
        slice_cmacIP = cmac_rx[34*BYTES-1:30*BYTES];
    endfunction

    function logic[2*BYTES-1:0] slice_udpLen(logic[CMAC_WIDTH-1:0] cmac_rx);
        slice_udpLen = cmac_rx[40*BYTES-1:38*BYTES];    
    endfunction


endpackage

