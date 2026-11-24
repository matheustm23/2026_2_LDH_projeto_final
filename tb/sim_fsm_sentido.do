# ===========================================================
# Arquivo  : sim_fsm_sentido.do
# Item     : 1 - Inversao do sentido de rotacao
# Descricao: Script do ModelSim para simular o fsm_sentido.
# Uso      : no ModelSim, File > Change Directory... e escolher a
#            pasta tb/ do projeto; depois, no console:
#              do sim_fsm_sentido.do
# ============================================================
vlib work
vlog ../rtl/sync_2ff.v ../rtl/fsm_sentido.v tb_fsm_sentido.v
vsim work.tb_fsm_sentido

add wave -position end sim:/tb_fsm_sentido/clk
add wave -position end sim:/tb_fsm_sentido/rst
add wave -position end sim:/tb_fsm_sentido/sw_dir
add wave -position end sim:/tb_fsm_sentido/dut/sw_sync
add wave -position end sim:/tb_fsm_sentido/dut/estado
add wave -position end -radix unsigned sim:/tb_fsm_sentido/dut/cnt
add wave -position end sim:/tb_fsm_sentido/troca
add wave -position end sim:/tb_fsm_sentido/pwm_en
add wave -position end sim:/tb_fsm_sentido/dir
add wave -position end sim:/tb_fsm_sentido/in1
add wave -position end sim:/tb_fsm_sentido/in2

run -all
wave zoom full
