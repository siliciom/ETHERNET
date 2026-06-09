# ==========================================
# Default Compile/Run Switches
# ==========================================

set comp_opts ""
set run_opts ""

# ==========================================
# Test Specific Switches
# ==========================================

if {$testname == "gmii_eth_normal_frame_test"} {

    #set comp_opts ""

    #set run_opts "+NO_OF_PKTS=200"

} elseif {$testname == "gmii_eth_max_size_frame_test"} {

    #set comp_opts "+define+HALF_DUPLEX"

    #set run_opts "+PAUSE_EN=1 +NUM_PKTS=200"

} elseif {$testname == "gmii_eth_min_size_frame_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_error_detection_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_vlan_tag_frame_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_preamble_corruption_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_frame_with_ext_bit_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_runt_good_fcs_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_runt_bad_fcs_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_bad_fcs_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

}  elseif {$testname == "gmii_eth_invalid_dest_addr_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_normal_frame_undefined_length_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_collision_detect_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_ipg_violation_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_len_payload_mismat_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_normal_payload_padding_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_vlan_payload_padding_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

}  elseif {$testname == "gmii_eth_pfc_frame_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_collision_in_middle_bytes_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

}  elseif {$testname == "gmii_eth_broadcast_frame_test"} {

    set comp_opts "+define+NO_OF_AGENTS=4"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_jabber_frame_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_pause_frame_basic_xon_xoff_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_simultaneous_pause_frame_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_pause_reserved_opcode_test"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_pause_frame_with_upadated_pause_time"} {

    #set comp_opts "+define+JUMBO_EN"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_multicast_frame_test"} {

    #set comp_opts "+define+NO_OF_AGENTS=4"

    #set run_opts "+PKT_SIZE=9000"

}


# ==========================================
# Valid Tests
# ==========================================
transcript quietly
set valid_tests {
    gmii_eth_normal_frame_test
    gmii_eth_max_size_frame_test
    gmii_eth_min_size_frame_test
    gmii_eth_error_detection_test
    gmii_eth_vlan_tag_frame_test
    gmii_eth_preamble_corruption_test
    gmii_eth_frame_with_ext_bit_test
    gmii_eth_runt_good_fcs_test
    gmii_eth_runt_bad_fcs_test
    gmii_eth_bad_fcs_test
    gmii_eth_invalid_dest_addr_test
    gmii_eth_normal_frame_undefined_length_test
    gmii_eth_collision_detect_test
    gmii_eth_ipg_violation_test
    gmii_eth_len_payload_mismat_test
    gmii_eth_normal_payload_padding_test
    gmii_eth_vlan_payload_padding_test
    gmii_eth_pfc_frame_test
    gmii_eth_collision_in_middle_bytes_test
    gmii_eth_broadcast_frame_test
    gmii_eth_jabber_frame_test
    gmii_eth_pause_frame_basic_xon_xoff_test
    gmii_eth_simultaneous_pause_frame_test
    gmii_eth_pause_reserved_opcode_test
    gmii_eth_pause_frame_with_upadated_pause_time
    gmii_eth_multicast_frame_test
}
# ==========================================
# Check whether test is valid
# ==========================================

if {[lsearch $valid_tests $testname] == -1} {

 

    puts "\033\[31m"

 

    puts ""
    puts "================================="
    puts "ERROR : INVALID TESTNAME"
    puts "================================="
    puts ""

 

    puts "Given Test : $testname"
    puts ""

 

    puts "\033\[0m"

 

    quit -f
}
# ==========================================
# Print Switches
# ==========================================

puts ""
puts "================================="
puts "Running Test      : $testname"
puts "Compile Switches : $comp_opts"
puts "Run Switches     : $run_opts"
puts "================================="

# ==========================================
# Library
# ==========================================

vlib work
vmap work work

# ==========================================
# Compile
# ==========================================

eval vlog -work work -sv \
./top/eth_gmii_interface.sv \
./top/eth_ui_interface.sv \
./top/eth_top.sv \
$comp_opts

# ==========================================
# Log/Wave files
# ==========================================
file mkdir sim/$testname
set logfile "./sim/$testname/${testname}.log"
set wavefile "./sim/$testname/${testname}.wlf"
set qwavefile "./sim/$testname/qwave.db"

# ==========================================
# Simulation
# ==========================================

eval vsim -debugDB -voptargs=+acc work.eth_top +UVM_TESTNAME=$testname +UVM_VERBOSITY=UVM_LOW $run_opts -l $logfile -qwavedb=+wavefile=$qwavefile
# ==========================================
# Logging
# ==========================================

add log -r /eth_top/*
add wave -r /eth_top/*

# ==========================================
# Prevent auto exit
# ==========================================

onfinish stop

# ==========================================
# Run Simulation
# ==========================================

run -all

after 1000

# ==========================================
# Read logfile
# ==========================================

set fp [open $logfile r]
set log_data [read $fp]
close $fp

# ==========================================
# PASS / FAIL
# ==========================================

if {[regexp {UVM_ERROR :\s+[1-9]} $log_data] || \
    [regexp {UVM_FATAL :\s+[1-9]} $log_data]} {

    puts "\033\[31m"
    puts "================================="
    puts "         TEST FAILED"
    puts "================================="
    puts "\033\[0m"

    puts ""
    puts "Log File  : [file normalize $logfile]"
    puts "Wave File : [file normalize $wavefile]"
    puts ""

} else {

    puts "\033\[32m"
    puts "================================="
    puts "         TEST PASSED"
    puts "================================="
    puts "\033\[0m"

    puts ""
    puts "Log File  : [file normalize $logfile]"
    puts "Wave File : [file normalize $wavefile]"
    puts ""
} 
quit -f

