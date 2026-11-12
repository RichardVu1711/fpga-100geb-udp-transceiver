#!/bin/sh

if [ -z "$COCOTB_SH_PATH" ]; then
    echo "COCOTB_SH_PATH is not set. Please set it to the path of cocotb's setup.sh script."
    exit 1
else
    source $COCOTB_SH_PATH
    conda activate llama311
fi
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <target>"
    exit 1
fi

if [ "$1" = "sim" ]; then
    shift
    HAS_UUT=0
    SCOPE="all"; FILTER=".*"
    for arg in "$@"; do
        case "$arg" in
            UUT=*)    HAS_UUT=1 ;;
            SCOPE=*)  SCOPE="${arg#SCOPE=}" ;;
            FILTER=*) FILTER="${arg#FILTER=}" ;;
        esac
    done

    if [ "$HAS_UUT" = "1" ]; then
        make -C scripts/cocotb ENTRY="$(pwd)" "$@"      # unchanged: targeted single build
    else
        run_unit() {
            for f in tests/rtl_sim/unit/*_tb.py; do
                [ -e "$f" ] || continue
                name=$(basename "$f" _tb.py)
                make -C scripts/cocotb ENTRY="$(pwd)" UUT="$name" UUT_TB="${name}_tb" FILTER="$FILTER"
            done
        }
        run_integration() {
            make -C scripts/cocotb ENTRY="$(pwd)" UUT=RXTop FILTER="$FILTER"   # UUT_TB auto-discovered
        }
        case "$SCOPE" in
            unit) run_unit ;;
            intg) run_integration ;;
            *)    run_unit; run_integration ;;
        esac
    fi
    exit 0
    exit 0
elif [ "$1" = "rtl" ]; then
    YS_TOP="$2"
    yosys -p "read_verilog src/*.v; 
            read_verilog -sv include/my_type.sv;
            read_verilog -sv src/*.sv; 
            read_verilog -sv include/*.sv;
            hierarchy -check -top $YS_TOP;
            write_json build/sim/RXTop.json"
    exit 0
elif [ "$1" = "clean" ]; then
    rm -rf "$(pwd)/build/sim"
else
    echo "Invalid arguments"
    exit 1
fi