

def swap_bytes32(v):
    return ((v & 0xFF) << 24) | ((v & 0xFF00) << 8) | ((v & 0xFF0000) >> 8) | ((v >> 24) & 0xFF)

def swap_bytes16(v):
    return ((v & 0xFF) << 8) | ((v >> 8) & 0xFF)

def adder_onec(byte_4s):
    acc = int(0)
    for b_1 in byte_4s:
        acc = acc + int.from_bytes(b_1,byteorder='big')
    # fold the add:
    acc = ((acc & 0xFFFF) + ((acc>>16)&0xFFFF))
    # Fold with the carry
    acc = ((acc & 0xFFFF) + ((acc>>16)&0xFFFF)) & 0xFFFF
    # convert to readable
    acc = acc.to_bytes(2,byteorder='big')
    print(f"adder result={acc.hex()}")
    return acc

def getHex(signal):
    capture_val = signal.value.to_bytes(byteorder='big');
    convert_val = capture_val
    byte_4 = []
    for i in range(0,len(convert_val),2):
        byte_4.append(convert_val[i:i+2])
    # adder_onec(byte_4) # TODO: Must Re-run the XCXC checksum tests!
    return byte_4

def print_hexes(str_name,strin):
    print(f"{str_name}=[{[pl.hex() for pl in strin]}]")

