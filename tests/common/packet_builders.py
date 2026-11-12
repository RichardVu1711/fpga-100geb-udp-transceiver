
def reverse_msg_inB(msg):
    reversed_msg = ""
    for i in range (0,len(msg),2):
        tmp = msg[(len(msg)-i-2):(len(msg)-i)]
        reversed_msg = reversed_msg + tmp
    return reversed_msg

def from_captured_arp():
    msg="068aa34f0000000000000000000000000000000000001032a8c00000000000000132a8c0ebebff999d6401000406000801000608ebebff999d64ffffffffffff"
    reversed_msg = reverse_msg_inB(msg)
    return reversed_msg

def from_corrupt_arp():
    """ Corrupt arp msg """
    msg="068aa34f0000000000000000000000000000000000001032a8c00000000000000132a8c0ebebff999d6401000406000801000008ebebff999d64ffffffffffff"
    reversed_msg = reverse_msg_inB(msg)
    return reversed_msg

def generate_test_arp():
    dest_mac    = "112233445566" 
    src_mac     = "649d99ffebeb"
    eth_type    = "0806"
    hw_type     = "0001"  #Ethernet
    proto_type  = "0008"  #ipv4
    hw_len      = "06"
    proto_len   = "04"
    opcode      = "0100"  #request
    senderMac   = "649d99ffebeb" # send from nic to cmac
    senderIP    = "c0a83201"
    targetMac   = "000000000000" # send from nic to cmac
    targetMac   = "c0a83211"     
    arp_test    = dest_mac + src_mac + eth_type + hw_type  +\
                proto_type + hw_len + proto_len + opcode + \
                senderMac + senderIP + targetMac + targetMac   
    return arp_test
