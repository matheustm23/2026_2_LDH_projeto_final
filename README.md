# Acionamento bidirecional e medição de velocidade de motor CC com encoder em FPGA

Projeto final da UC Linguagens de Descrição de Hardware (LDH), IFSC Chapecó, 2026/2.
Dupla: **Matheus** e **Luís**.

A DE10-Lite comanda um motor JGB37-520 (12 V, 60 RPM) por uma ponte H L298N. A chave SW0 escolhe o sentido de rotação, com uma pausa de 0,5 s a cada inversão. Os botões KEY1/KEY0 ajustam o PWM de 0 a 100 %, o encoder é lido em x4, a velocidade é medida em RPM e o resultado aparece nos displays de 7 segmentos.

## Status dos itens

| Item | Função | Responsável | Status |
|---|---|---|---|
| 1 | FSM de inversão de sentido (SW0, pausa de 0,5 s) | Matheus | concluído |
| 2 | Ajuste do setpoint por KEY1/KEY0 (debounce e borda) | Luís | concluído |
| 3 | Gerador de PWM para o ENA da L298N | Matheus | concluído |
| 4 | Leitura do encoder (sincronizador 2 FF, decodificação x4) | Luís | concluído |
| 5 | Medição de velocidade em RPM | Matheus | concluído |
| 6 | Displays de 7 segmentos (RPM ou setpoint) e LEDs | Luís | pendente |

## Hardware

- Placa Terasic DE10-Lite (Intel MAX 10, 10M50DAF484C6GES), clock de 50 MHz
- Motor JGB37-520, 12 V, 60 RPM, com encoder Hall A/B (11 pulsos por volta do motor)
- Ponte H L298N (jumper do ENA retirado)
- Fonte externa de 12 V

## Pinagem

| Sinal | Recurso da placa | Detalhe |
|---|---|---|
| Reset | SW9 | ativo em 1 |
| Sentido | SW0 | 1 = horário, 0 = anti-horário |
| Seleção do display | SW1 | 0 = posição do encoder, 1 = RPM×10 (provisório até o item 6) |
| Aumentar setpoint | KEY1 | +5 % (item 2) |
| Reduzir setpoint | KEY0 | −5 % (item 2) |
| ENA (PWM) | GPIO[0], pino 1 do header | saída para a L298N |
| IN1 | GPIO[1], pino 2 | saída para a L298N |
| IN2 | GPIO[2], pino 3 | saída para a L298N |
| Encoder A | GPIO[3], pino 4 | entrada, pull-up fraco ligado |
| Encoder B | GPIO[4], pino 5 | entrada, pull-up fraco ligado |
| Alimentação do encoder | pino 29 (3,3 V) e pino 30 (GND) | os pinos da FPGA só aceitam 3,3 V |
| LEDR0 / LEDR1 | | sentido horário / anti-horário |
| LEDR2 | | pausa de troca de sentido em andamento |
| LEDR9..LEDR3 | | setpoint em binário (provisório até o item 6) |
| HEX5..HEX0 | | posição do encoder ou RPM×10, em hexadecimal, conforme a SW1 (provisório até o item 6) |

O GND da fonte, da L298N e da DE10-Lite precisa ser comum (pino 12 ou 30 do header).

## Funcionamento atual

- **Item 1:** ao mudar a SW0, o ENA vai a 0 e o LEDR2 acende por 0,5 s. Depois o sentido troca (IN1/IN2) e o PWM volta. Se a chave voltar à posição original durante a pausa, o sentido não muda.
- **Item 2:** cada toque em KEY1 soma 5 % ao setpoint e cada toque em KEY0 tira 5 %, entre 0 e 100 %. Os botões passam por sincronizador, debounce de 10 ms e detector de borda: segurar o botão conta um passo só. Até o item 6 entrar, o setpoint aparece em binário nos LEDR9..LEDR3 (100 % = 1100100).
- **Item 3:** o ENA recebe um PWM de 1 kHz com resolução de 1 % (100 passos por período), seguindo o setpoint do item 2. O duty novo só vale a partir do período seguinte, então mudar o setpoint não gera pulso cortado. Durante a pausa de troca de sentido o PWM fica em 0 e, quando volta, começa um período inteiro. Com setpoint baixo (abaixo de uns 20 a 30 %) o motor pode não ter força para girar, o que é normal.
- **Item 4:** os canais A e B do encoder passam por sincronizador de 2 flip-flops e por um filtro de ruído de 1 µs (rejeita pulsos curtos induzidos pelo PWM do motor). Cada borda dos dois canais conta uma unidade (decodificação x4): 44 contagens por volta do eixo do motor. A posição soma no sentido horário e subtrai no anti-horário. Até o item 6 entrar, com a SW1 em 0 a posição aparece em hexadecimal nos displays (HEX5..HEX0), para a calibração abaixo. Valores negativos aparecem em complemento de 2 (FFFFxx).
- **Item 5:** a velocidade do eixo de saída é medida contando os pulsos do encoder numa janela de tempo escolhida para que a contagem já seja o RPM × 10, sem divisão no hardware: T = 600 / CPR_SAIDA s. Com o CPR provisório de 3960, a janela é de 0,1515 s (cerca de 6,6 leituras por segundo) e a resolução é de 0,1 RPM. Até o item 6 entrar, com a SW1 em 1 os displays mostram o RPM × 10 em hexadecimal (ex.: `00020B` = 523 = 52,3 RPM).
- Depois de gravar a placa, liga e desliga a SW9 uma vez para garantir o reset.

## Calibração do encoder (CPR_SAIDA)

A etiqueta do motor não informa a redução, então o número de contagens por volta do eixo de saída (`CPR_SAIDA`, usado no item 5) é medido assim:

1. Com o setpoint em 0 (motor parado) e a SW1 em 0, marca o eixo de saída com um pedaço de fita e liga/desliga a SW9: os displays mostram `000000`.
2. Gira o eixo de saída exatamente **10 voltas** no sentido horário, olhando de frente para o eixo. Se a caixa de redução estiver dura demais para girar à mão, liga o motor com setpoint baixo, conta as voltas pela fita, desliga a fonte de 12 V perto da 10ª volta e ajusta à mão até a fita voltar à marca (o encoder continua contando, porque é alimentado pela placa).
3. Converte o número dos displays de hexadecimal para decimal e divide por 10.
4. O resultado deve ficar perto de 44 × redução. Exemplos: 1:90 → 3960 (10 voltas = `009AB0`); 1:168 → 7392 (10 voltas = `0120C0`). Usar o valor exato 44 × redução da redução encontrada.

Para conferir o sentido: com a SW0 em 1 (LEDR0 aceso) e o motor girando, a posição tem que **subir**. Se descer, troca `INVERTE` para `1'b1` na instância `u_encoder_x4` do topo.

Depois de medir, troca o `CPR_SAIDA` na instância `u_rpm_meter` do topo (hoje está com o valor provisório 3960). A janela de medição é recalculada sozinha.

**CPR_SAIDA medido:** a preencher depois do teste na placa.

## Estrutura

```
├── 2026_2_LDH_projeto_final.qpf / .qsf   # projeto Quartus (pinos do Golden Top)
├── 2026_2_LDH_projeto_final.sdc          # restricao do clock de 50 MHz
├── DE10_LITE_Golden_Top.v                # topo: instancia e liga os modulos
├── proposta.md                           # proposta entregue ao professor
├── rtl/                                  # modulos Verilog
│   ├── sync_2ff.v                        # sincronizador de 2 flip-flops
│   ├── fsm_sentido.v                     # item 1
│   ├── debounce.v                        # filtro de repique (item 2)
│   ├── setpoint_ctrl.v                   # item 2
│   ├── pwm_gen.v                         # item 3
│   ├── encoder_x4.v                      # item 4
│   ├── rpm_meter.v                       # item 5
│   └── hex7seg.v                         # decodificador de display (itens 4 e 6)
└── tb/                                   # testbenches e scripts do ModelSim
    ├── tb_fsm_sentido.v
    ├── sim_fsm_sentido.do
    ├── tb_setpoint_ctrl.v
    ├── sim_setpoint_ctrl.do
    ├── tb_pwm_gen.v
    ├── sim_pwm_gen.do
    ├── tb_encoder_x4.v
    ├── sim_encoder_x4.do
    ├── tb_hex7seg.v
    ├── sim_hex7seg.do
    ├── tb_rpm_meter.v
    └── sim_rpm_meter.do
```

## Como compilar e simular

- **Quartus Prime 18.1:** abrir `2026_2_LDH_projeto_final.qpf`, compilar (Ctrl+L) e gravar a placa pelo Programmer.
- **ModelSim:** em File > Change Directory, escolher a pasta `tb/` e rodar o script do módulo no console (`do sim_fsm_sentido.do`, `do sim_setpoint_ctrl.do`, `do sim_pwm_gen.do`, `do sim_encoder_x4.do`, `do sim_hex7seg.do`, `do sim_rpm_meter.do`). O testbench imprime `PASS` ou `FAIL` no final.
