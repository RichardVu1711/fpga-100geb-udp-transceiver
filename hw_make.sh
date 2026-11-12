#!/bin/sh

export ROOT_DIR="${ROOT_DIR:-$(pwd)}"
HW_DIR=build/
TCL_DIR=scripts/tcl/
RTL_DIR=$ROOT_DIR/src/
HW_PROJECT=qsfp100g

echo "==== Building the project ===="
echo "ROOT_DIR: $ROOT_DIR"
# check the number of arguments
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <target>"
    exit 1
fi

if [ "$1" = "hw" ]; then
    if [ -z "$BOARD_REPO_PATH" ]; then
        echo "BOARD_REPO_PATH is not set. Please set it to the path of the rfsoc4x2 board files on this server."
        exit 1
    fi
    force=0
    for arg in "$@"; do
        echo "Argument: $arg"
        if [ "$arg" = "-f" ]; then
            force=1
        fi
    done
    # copy constraints to the target project
    cp -r $ROOT_DIR/scripts/constraints/*.xdc $HW_DIR/
    # construct the project
    vivado -mode batch -source $TCL_DIR/qsfp100g.tcl \
        -log $HW_DIR/qsfp100g.log -nojournal \
        -tclargs --origin_dir $HW_DIR --project_name $HW_PROJECT \
        --tcl_dir $TCL_DIR --src_dir $RTL_DIR --board_repo $BOARD_REPO_PATH --force $force
    exit 0
elif [ "$1" = "bit" ]; then
    force=0
    for arg in "$@"; do
        if [ "$arg" = "-f" ]; then
            force=1
        fi
    done

    # open the Vivado project and generate the bitstream
    # (-f forces a re-synth/re-impl even if the project is already up-to-date)
    vivado -mode batch -source $TCL_DIR/genbitstream.tcl \
        -log $HW_DIR/qsfp100g.log -nojournal \
        -tclargs --origin_dir $HW_DIR --project_name $HW_PROJECT \
        --force $force
    exit 0
elif [ "$1" = "pkg" ]; then
    shift
    # Copy necessary files 
    mkdir -p $ROOT_DIR/build/firmware_pkg
    cp -r $ROOT_DIR/firmware/* $ROOT_DIR/build/firmware_pkg
    cp -r $ROOT_DIR/scripts/gcc/* $ROOT_DIR/build/firmware_pkg
    find $ROOT_DIR/build/$HW_PROJECT/ -iname "*.xsa" -exec cp {} $ROOT_DIR/build/firmware_pkg \;
    find $ROOT_DIR/build/$HW_PROJECT/ -iname "*.bit" -exec cp {} $ROOT_DIR/build/firmware_pkg \;
    find $ROOT_DIR/build/$HW_PROJECT/ -iname "*.ltx" -exec cp {} $ROOT_DIR/build/firmware_pkg \;
    # move this to the rf_4x2
    scp -r  $ROOT_DIR/build/firmware_pkg rf_4x2:dma/remote_4x2/
    # ssh -tt rf_4x2 "cd /home/xilinx/dma/remote_4x2/firmware_pkg && sudo ./pynq_exec.sh $*"
    
    exit 0
elif [ "$1" = "clean" ]; then
    echo "rm the projects at $HW_DIR/$HW_PROJECT"
    rm -rf $HW_DIR/$HW_PROJECT
    rm -rf $HW_DIR/firmware
    rm $HW_DIR/*.log
    exit 0
else
    echo "Invalid option"
    exit 1
fi
