# ============================================================
# Arquivo  : sim_pwm_gen.do
# Item     : 3 - Gerador de PWM para o ENA da L298N
# Descricao: Script do ModelSim para simular o pwm_gen.
# Uso      : no ModelSim, File > Change Directory... e escolher a
#            pasta tb/ do projeto; depois, no console:
#              do sim_pwm_gen.do
# ============================================================
vlib work
vlog ../rtl/pwm_gen.v tb_pwm_gen.v
vsim work.tb_pwm_gen

add wave -position end sim:/tb_pwm_gen/clk
add wave -position end sim:/tb_pwm_gen/rst
add wave -position end sim:/tb_pwm_gen/en
add wave -position end -radix unsigned sim:/tb_pwm_gen/duty
add wave -position end -radix unsigned sim:/tb_pwm_gen/dut/duty_reg
add wave -position end -radix unsigned sim:/tb_pwm_gen/dut/passo
add wave -position end sim:/tb_pwm_gen/pwm
add wave -position end sim:/tb_pwm_gen/pwm_real

run -all
wave zoom full
