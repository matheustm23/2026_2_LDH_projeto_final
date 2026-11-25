# ============================================================
# Arquivo  : sim_hex7seg.do
# Item     : 4 - Leitura do encoder (decodificador de display)
# Descricao: Script do ModelSim para simular o hex7seg.
# Uso      : no ModelSim, File > Change Directory... e escolher a
#            pasta tb/ do projeto; depois, no console:
#              do sim_hex7seg.do
# ============================================================
vlib work
vlog ../rtl/hex7seg.v tb_hex7seg.v
vsim work.tb_hex7seg

add wave -position end -radix hexadecimal sim:/tb_hex7seg/hex
add wave -position end -radix binary sim:/tb_hex7seg/seg

run -all
wave zoom full
