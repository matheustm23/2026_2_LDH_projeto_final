# ============================================================
# Arquivo  : sim_setpoint_ctrl.do
# Item     : 2 - Ajuste do setpoint do PWM
# Descricao: Script do ModelSim para simular o setpoint_ctrl.
# Uso      : no ModelSim, File > Change Directory... e escolher a
#            pasta tb/ do projeto; depois, no console:
#              do sim_setpoint_ctrl.do
# ============================================================
vlib work
vlog ../rtl/sync_2ff.v ../rtl/debounce.v ../rtl/setpoint_ctrl.v tb_setpoint_ctrl.v
vsim work.tb_setpoint_ctrl

add wave -position end sim:/tb_setpoint_ctrl/clk
add wave -position end sim:/tb_setpoint_ctrl/rst
add wave -position end sim:/tb_setpoint_ctrl/key_up_n
add wave -position end sim:/tb_setpoint_ctrl/dut/up_db
add wave -position end sim:/tb_setpoint_ctrl/dut/up_press
add wave -position end sim:/tb_setpoint_ctrl/key_down_n
add wave -position end sim:/tb_setpoint_ctrl/dut/down_db
add wave -position end sim:/tb_setpoint_ctrl/dut/down_press
add wave -position end sim:/tb_setpoint_ctrl/ajuste
add wave -position end -radix unsigned sim:/tb_setpoint_ctrl/duty

run -all
wave zoom full
