
vlib work

vmap work work

vlog -work work  -cover bsectf +fcover -sv -debug -incr -mfcu -suppress  TOP/ace_interface.sv TOP/ace_vip_package.sv  TOP/ace_rtl_top.sv TOP/ace_rtl_interconnect.sv TOP/ace_rtl_memory.sv TOP/ace_top.sv +define+PARAMETER_32

vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_fixed_burst_test +TEST=WRITE_FOLLOWED_BY_READ_FIXED_TEST +MODE=1

#### VIP ####
#vlog -work work  -cover bsectf +fcover -sv -debug -incr -mfcu -suppress  TOP/ace_interface.sv TOP/ace_vip_package.sv  TOP/ace_top.sv +define+VIP +define+PARAMETER_32

### READ SHARED ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_snooping_readshared_test  +MODE=0
#add log -r /ace_top/*
run -all
#coverage save cvg_report1.ucdb

#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_fixed_burst_w2_test +TEST=BASIC_WRITE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report34.ucdb
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_fixed_burst_w2_test +TEST=BASIC_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report35.ucdb


### FIXED BURST ## 
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_fixed_burst_test +TEST=BASIC_WRITE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report2.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_fixed_burst_test +TEST=BASIC_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report3.ucdb


#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_fixed_burst_test +TEST=WRITE_FOLLOWED_BY_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report4.ucdb


#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_fixed_burst_test +TEST=WRITE_AND_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report5.ucdb
#
#
### INCR ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_incr_burst_test +TEST=BASIC_WRITE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report6.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_incr_burst_test +TEST=BASIC_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report7.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report8.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_incr_burst_test +TEST=WRITE_AND_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report9.ucdb
#
#
### WRAP ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_wrap_burst_test +TEST=BASIC_WRITE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report10.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_wrap_burst_test +TEST=BASIC_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report11.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_wrap_burst_test +TEST=WRITE_FOLLOWED_BY_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report12.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_wrap_burst_test +TEST=WRITE_AND_READ_TEST +MODE=0
#add log -r /ace_top/*
#run -all
#coverage save cvg_report13.ucdb
#
#
## UNALIGNED FIXED BURST ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_fixed_burst_test +TEST=WRITE_FOLLOWED_BY_READ_FIXED_1_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report14.ucdb
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_fixed_burst_test +TEST=WRITE_FOLLOWED_BY_READ_FIXED_9_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report15.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_fixed_burst_test +TEST=WRITE_FOLLOWED_BY_READ_FIXED_17_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report16.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_fixed_burst_test +TEST=WRITE_FOLLOWED_BY_READ_FIXED_25_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report17.ucdb
#
#
### UNALIGNED INCR TEST ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_INCR_3_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report18.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_INCR_11_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report19.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_INCR_19_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report20.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_INCR_27_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report21.ucdb
#
#
### UNALIGNED NARROW FIXED BURST ###
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_narrow_fixed_burst_test +TEST=WRITE_FOLLOWED_BY_READ_FIXED_BYTE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report22.ucdb
#
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_narrow_fixed_burst_test +TEST=WRITE_FOLLOWED_BY_READ_FIXED_HWORD_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report23.ucdb
#
#
## UNALIGNED NARROW INCR BURST ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_narrow_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_INCR_BYTE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report24.ucdb
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_unaligned_narrow_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_INCR_HWORD_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report25.ucdb
#
#
## ALIGNED NARROW FIXED ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_aligned_narrow_fixed_burst_test +test_name=WRITE_FOLLOWED_BY_READ_FIXED_BYTE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
###coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report26.ucdb
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_aligned_narrow_fixed_burst_test +test_name=WRITE_FOLLOWED_BY_READ_FIXED_HWORD_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report27.ucdb
#
## ALIGNED NARROW INCR ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_aligned_narrow_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_INCR_BYTE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report28.ucdb
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_aligned_narrow_incr_burst_test +TEST=WRITE_FOLLOWED_BY_READ_INCR_HWORD_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report29.ucdb
#
#
# ALIGNED NARROW WRAP ##
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_aligned_narrow_wrap_burst_test +TEST=WRITE_FOLLOWED_BY_READ_WRAP_BYTE_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report30.ucdb
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_aligned_narrow_wrap_burst_test +TEST=WRITE_FOLLOWED_BY_READ_WRAP_HWORD_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report31.ucdb
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_aligned_narrow_wrap_burst_test +TEST=WRITE_FOLLOWED_BY_READ_WRAP_BYTE_LEN_1_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report32.ucdb
#
#vsim -debugDB -cvgperinstance -coverage -c -do coverage ace_top +UVM_TESTNAME=ace_write_and_read_no_snoop_aligned_narrow_wrap_burst_test +TEST=WRITE_FOLLOWED_BY_READ_WRAP_HWORD_LEN_1_TEST +MODE=0
#add log -r /ace_top/*
#run -all
##coverage report -all -codeALL -cvg -byinst
#coverage save cvg_report33.ucdb
#

#vcover merge C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/merged_cov.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report32.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report33.ucdb
# C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report3.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report4.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report5.ucdb
#C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report6.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report7.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report8.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report9.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report10.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report11.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report12.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report13.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report14.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report15.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report16.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report17.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report18.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report19.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report20.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report21.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report22.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report23.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report24.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report25.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report26.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report27.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report28.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report29.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report30.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report31.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report32.ucdb C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report33.ucdb 
#C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report34.ucdb 
#C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/cvg_report35.ucdb 



##Below command should be run in command prompt
#vcover report -details -html C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/merged_cov.ucdb

write transcript C:/Users/varsh/Downloads/ace_vip_project_proper_readshared_with_arbitration/ace_vip_project_V3.0/ace_transcript.txt


##coverage save -all -verbose -codeALL -assert -cvg -details -directive
##vcover report first_cov.ucdb -all
##coverage report -all -codeALL -cvg -byinst
##coverage save original.ucdb
add wave -r  /ace_top/ACLK
##add wave -r /ace_top/ace_vif/*
add wave -r /ace_top/ace_vif_0/mdriver_cb/*
add wave -r /ace_top/ace_vif_0/sdriver_cb/*
add wave -r /ace_top/ace_vif_0/mmonitor_cb/*
add wave -r /ace_top/ace_vif_0/smonitor_cb/*
add wave -r /ace_top/ace_vif_1/sdriver_cb/*
add wave -r /ace_top/ace_vif_1/mdriver_cb/*
add wave -r /ace_top/ace_vif_1/mmonitor_cb/*
add wave -r /ace_top/ace_vif_1/smonitor_cb/*
##add wave -r /uvm_root/uvm_test_top/ace_env/ace_s_agent_top/ace_sagent/ace_sdriver/*
##add wave -r /ace_top/ace_vif_1/*
