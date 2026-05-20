vlib work

vmap work work

# Compile interfaces first
vlog -work work -sv ./top/eth_gmii_interface.sv
vlog -work work -sv ./top/eth_ui_interface.sv

# Compile package
#vlog -work work -sv ./config/eth_pkg.sv

# Compile top
vlog -work work -sv ./top/eth_top.sv

# UVM test name
set testname "eth_base_test"

# Log file path
set logfile "./sim/${testname}.log"

# Run simulation
vsim work.eth_top +UVM_TESTNAME=$testname +UVM_VERBOSITY=UVM_LOW -l $logfile

add log -r /eth_top/*

add wave -r /eth_top/*

run -all
 
