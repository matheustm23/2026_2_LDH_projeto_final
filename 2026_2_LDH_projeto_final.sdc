# ============================================================
# Arquivo  : 2026_2_LDH_projeto_final.sdc
# Item     : 3 - Restricoes de tempo do projeto
# Autor    : Matheus
# Descricao: Informa ao Timing Analyzer o clock de 50 MHz da
#            placa. As entradas (chaves, botoes e encoder) sao
#            assincronas e passam por sincronizador de 2 FFs, e as
#            saidas (LEDs, displays e ponte H) nao tem requisito de
#            tempo; por isso esses caminhos sao marcados como
#            false path.
# ============================================================

# Clock de 50 MHz (periodo de 20 ns)
create_clock -name MAX10_CLK1_50 -period 20.000 [get_ports {MAX10_CLK1_50}]

# Incerteza do clock calculada pelo Quartus
derive_clock_uncertainty

# Entradas assincronas (sincronizadas internamente)
set_false_path -from [get_ports {SW[*]}]
set_false_path -from [get_ports {KEY[*]}]
set_false_path -from [get_ports {GPIO[*]}]

# Saidas sem requisito de tempo (LEDs, displays, ponte H e as demais
# saidas do Golden Top que nao sao usadas)
set_false_path -to [all_outputs]
