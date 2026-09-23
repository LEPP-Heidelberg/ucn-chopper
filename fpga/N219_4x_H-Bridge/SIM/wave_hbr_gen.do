onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /hbr_gen_tb/addr
add wave -noupdate /hbr_gen_tb/clk
add wave -noupdate /hbr_gen_tb/control_afbr
add wave -noupdate /hbr_gen_tb/din
add wave -noupdate /hbr_gen_tb/dout
add wave -noupdate -expand /hbr_gen_tb/h_inp
add wave -noupdate /hbr_gen_tb/reset
add wave -noupdate /hbr_gen_tb/we
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/hbr_sm
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/pwm_cnt
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/pwm_reset
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/pwm_tick
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/pwr_code
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/pwr_on
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/sm_addr
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/sm_acnt
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/sm_ramd
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/ctrl_off
add wave -noupdate /hbr_gen_tb/dut/sm_1_i/ctrl_on
add wave -noupdate -expand /hbr_gen_tb/busy
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {471640464 ps} 0} {{Cursor 2} {483130454 ps} 0}
quietly wave cursor active 2
configure wave -namecolwidth 215
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits us
update
WaveRestoreZoom {336355100 ps} {730906524 ps}
