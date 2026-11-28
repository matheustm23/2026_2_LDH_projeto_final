# ============================================================
# Arquivo  : sim_rpm_meter.do
# Item     : 5 - Medicao de velocidade em RPM
# Descricao: Script do ModelSim para simular o rpm_meter.
# Uso      : no ModelSim, File > Change Directory... e escolher a
#            pasta tb/ do projeto; depois, no console:
#              do sim_rpm_meter.do
# ============================================================
vlib work
vlog ../rtl/rpm_meter.v tb_rpm_meter.v
vsim work.tb_rpm_meter

add wave -position end sim:/tb_rpm_meter/clk
add wave -position end sim:/tb_rpm_meter/rst
add wave -position end -radix decimal sim:/tb_rpm_meter/r10_alvo
add wave -position end sim:/tb_rpm_meter/step
add wave -position end -radix unsigned sim:/tb_rpm_meter/dut/t_cnt
add wave -position end -radix unsigned sim:/tb_rpm_meter/dut/pulsos
add wave -position end sim:/tb_rpm_meter/rpm_valid
add wave -position end -radix unsigned sim:/tb_rpm_meter/rpm_x10

run -all
wave zoom full
