#========================================================
# CLEAN WORK LIBRARY
#========================================================
if {[file exists work]} {
    vdel -all
}
 
#========================================================
# LIBRARY
#========================================================
vlib work
vmap work work
 
#========================================================
# TEST LIST
#========================================================
set test_list {
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
    gmii_eth_jabber_frame_test
    gmii_eth_pause_frame_basic_xon_xoff_test
    gmii_eth_simultaneous_pause_frame_test
    gmii_eth_pause_reserved_opcode_test
    gmii_eth_pause_frame_with_upadated_pause_time
    gmii_eth_multicast_frame_test
    gmii_eth_collision_in_middle_bytes_test
    gmii_eth_max_collision_attempt_test
    gmii_eth_late_collision_test
    gmii_eth_long_frame_test
    gmii_eth_frame_bursting_test

    }

#========================================================
# DIRECTORIES
#========================================================
file mkdir Regression
file mkdir coverage_reports
 
#========================================================
# PASS / FAIL VARIABLES
#========================================================
proc check_result {logfile testname} {
 
    # Check log file exists
    if {![file exists $logfile]} {
        echo "❌ FAILED : $testname (log file not found)"
        return "FAIL"
    }
 
    set fh [open $logfile r]
    set content [read $fh]
    close $fh
 
    set fatal_count 0
    set error_count 0
 
    foreach line [split $content "\n"] {
 
        if {[regexp {Number of FATAL reports\s*:\s*(\d+)} $line match count]} {
            set fatal_count $count
        }
 
        if {[regexp {Number of ERROR reports\s*:\s*(\d+)} $line match count]} {
            set error_count $count
        }
    }
 
    if {$fatal_count == 0 && $error_count == 0} {
        echo "✅ PASSED : $testname"
        return "PASS"
    } else {
        echo "❌ FAILED : $testname (FATAL=$fatal_count ERROR=$error_count)"
        return "FAIL"
    }
}
 
#========================================================
# REGRESSION LOOP
#========================================================
set pass_count 0
set fail_count 0
set fail_list {}
 
set last_comp_opts "__NONE__" 
foreach testname $test_list {

# ==========================================
# Default Compile/Run Switches
# ==========================================
set comp_opts ""
set run_opts ""

# ==========================================
# Test Specific Switches
# ==========================================

if {$testname == "gmii_eth_normal_frame_test"} {


    #set run_opts "+NO_OF_PKTS=200"

} elseif {$testname == "gmii_eth_frame_with_ext_bit_test"} {

    set comp_opts "+define+HALF_DUPLEX"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_collision_detect_test"} {

    set comp_opts "+define+HALF_DUPLEX"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_collision_in_middle_bytes_test"} {

    set comp_opts "+define+HALF_DUPLEX"

    #set run_opts "+PKT_SIZE=9000"

}  elseif {$testname == "gmii_eth_broadcast_frame_test"} {

    set comp_opts "+define+NO_OF_AGENTS=4"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_multicast_frame_test"} {

    set comp_opts "+define+NO_OF_AGENTS=4"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_max_collision_attempt_test"} {

    set comp_opts "+define+HALF_DUPLEX"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_late_collision_test"} {

    set comp_opts "+define+HALF_DUPLEX"

    #set run_opts "+PKT_SIZE=9000"

} elseif {$testname == "gmii_eth_frame_bursting_test"} {

    set comp_opts "+define+HALF_DUPLEX"

}


    puts "TEST      : $testname"
    puts "COMP_OPTS : $comp_opts"
    puts "RUN_OPTS  : $run_opts" 
 
 
    echo "======================================="
    echo "RUNNING TEST : $testname"
    echo "======================================="
    # UCDB FILE NAME
#====================================================
# COMPILE
#====================================================
if {$comp_opts ne $last_comp_opts} {

    puts "================================="
    puts "COMPILING"
    puts "TEST      : $testname"
    puts "COMP_OPTS : <$comp_opts>"
    puts "================================="

            eval vlog -work work -cover bsectf +fcover -sv -incr -mfcu \
                top/eth_gmii_interface.sv \
                top/eth_ui_interface.sv \
                top/eth_top.sv \
    		$comp_opts 
		set last_comp_opts $comp_opts
} else {
    puts "================================="
    puts "SKIPPING COMPILE"
    puts "TEST      : $testname"
    puts "COMP_OPTS : <$comp_opts>"
    puts "================================="
}
 
 
set ucdb_file "coverage_reports/${testname}.ucdb"
 
    #====================================================
    # SIMULATION COMMAND
    #====================================================
    exec vsim -c \
        -coverage \
        -cvgperinstance \
        -debugDB \
        -batch \
         +acc \
        work.eth_top \
        +UVM_TESTNAME=$testname \
        -l Regression/${testname}.log \
	$run_opts \
        -do "add log -r /*; coverage save -onexit $ucdb_file; run -all; quit -f"
          catch {eval exec $sim_cmd} sim_result
 
   #====================================================
    # CHECK PASS / FAIL
    #====================================================
    set result [check_result Regression/${testname}.log $testname]
 
    if {$result == "PASS"} {
        incr pass_count
    } else {
        incr fail_count
        lappend fail_list $testname
    }
 
    echo "COMPLETED : $testname"
}
 
#========================================================
# SHOW GENERATED UCDB FILES
#========================================================
echo "======================================="
echo "GENERATED COVERAGE FILES"
echo "======================================="
set ucdb_files [glob -nocomplain coverage_reports/*.ucdb]
 
if {[llength $ucdb_files] == 0} {
    echo "❌ NO UCDB FILES FOUND"
} else {
    foreach f $ucdb_files {
        echo $f
    }
}
 
#========================================================
# MERGE COVERAGE
#========================================================
echo "======================================="
echo "MERGING COVERAGE DATABASES"
echo "======================================="
 
set ucdb_files [glob -nocomplain coverage_reports/*.ucdb]
set ucdb_files [lsearch -all -inline -not $ucdb_files "coverage_reports/merged_cov.ucdb"]
 
if {[llength $ucdb_files] == 0} {
    echo "❌ NO UCDB FILES TO MERGE"
} else {
    eval vcover merge coverage_reports/merged_cov.ucdb $ucdb_files
}
 
#========================================================
# GENERATE COVERAGE REPORT
#========================================================
echo "======================================="
echo "GENERATING COVERAGE REPORT"
echo "======================================="
 
vcover report -details -html coverage_reports/merged_cov.ucdb
 
#========================================================
# FINAL REGRESSION SUMMARY
#========================================================
echo "======================================="
echo "        REGRESSION SUMMARY"
echo "======================================="
 
echo "TOTAL  TESTS : [llength $test_list]"
echo "PASSED TESTS : $pass_count"
echo "FAILED TESTS : $fail_count"
 
echo "======================================="
 
#========================================================
# PRINT FAILED TESTS
#========================================================
if {$fail_count > 0} {
    echo "FAILED TESTCASES:"
    foreach ft $fail_list {
        echo "   ❌ $ft"
    }
}
 
echo "======================================="
echo "REGRESSION COMPLETED"
echo "======================================="
quit -f

