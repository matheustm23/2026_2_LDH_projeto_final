# ============================================================
# Arquivo  : sim_encoder_x4.do
# Item     : 4 - Leitura do encoder
# Descricao: Script do ModelSim para simular o encoder_x4.
# Uso      : no ModelSim, File > Change Directory... e escolher a
#            pasta tb/ do projeto; depois, no console:
#              do sim_encoder_x4.do
# ============================================================
vlib work
vlog ../rtl/sync_2ff.v ../rtl/encoder_x4.v tb_encoder_x4.v
vsim work.tb_encoder_x4

add wave -position end sim:/tb_encoder_x4/clk
add wave -position end sim:/tb_encoder_x4/rst
add wave -position end sim:/tb_encoder_x4/enc_a
add wave -position end sim:/tb_encoder_x4/enc_b
add wave -position end sim:/tb_encoder_x4/dut/a_f
add wave -position end sim:/tb_encoder_x4/dut/b_f
add wave -position end sim:/tb_encoder_x4/step
add wave -position end sim:/tb_encoder_x4/dir_enc
add wave -position end -radix decimal sim:/tb_encoder_x4/pos
add wave -position end -radix decimal sim:/tb_encoder_x4/pos_inv

run -all
wave zoom full
