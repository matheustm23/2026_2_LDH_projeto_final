# Acionamento bidirecional e medição de velocidade de motor CC com encoder em FPGA

Projeto final da UC Linguagens de Descrição de Hardware (LDH), IFSC Chapecó, 2026/2.
Dupla: **Matheus** e **Luís**.

A DE10-Lite comanda um motor JGB37-520 (12 V, 60 RPM) por uma ponte H L298N. A chave SW0 escolhe o sentido de rotação, com uma pausa de 0,5 s a cada inversão. Os botões KEY1/KEY0 ajustam o PWM de 0 a 100 %, o encoder é lido em x4, a velocidade é medida em RPM e o resultado aparece nos displays de 7 segmentos.

## Status dos itens

| Item | Função | Responsável | Status |
|---|---|---|---|
| 1 | FSM de inversão de sentido (SW0, pausa de 0,5 s) | Matheus | concluído |
| 2 | Ajuste do setpoint por KEY1/KEY0 (debounce e borda) | Luís | pendente |
| 3 | Gerador de PWM para o ENA da L298N | Matheus | pendente |
| 4 | Leitura do encoder (sincronizador 2 FF, decodificação x4) | Luís | pendente |
| 5 | Medição de velocidade em RPM | Matheus | pendente |
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
| Aumentar setpoint | KEY1 | +5 % (item 2) |
| Reduzir setpoint | KEY0 | −5 % (item 2) |
| ENA (PWM) | GPIO[0], pino 1 do header | saída para a L298N |
| IN1 | GPIO[1], pino 2 | saída para a L298N |
| IN2 | GPIO[2], pino 3 | saída para a L298N |
| Encoder A | GPIO[3], pino 4 | entrada (item 4) |
| Encoder B | GPIO[4], pino 5 | entrada (item 4) |
| Alimentação do encoder | pino 29 (3,3 V) e pino 30 (GND) | os pinos da FPGA só aceitam 3,3 V |
| LEDR0 / LEDR1 | | sentido horário / anti-horário |
| LEDR2 | | pausa de troca de sentido em andamento |
| HEX0..HEX5 | | RPM ou setpoint (item 6) |

O GND da fonte, da L298N e da DE10-Lite precisa ser comum (pino 12 ou 30 do header).

## Funcionamento atual

- **Item 1:** ao mudar a SW0, o ENA vai a 0 e o LEDR2 acende por 0,5 s. Depois o sentido troca (IN1/IN2) e o ENA volta a 1. Até o item 3 entrar, o motor gira a 100 %. Se a chave voltar à posição original durante a pausa, o sentido não muda.

## Estrutura

```
├── 2026_2_LDH_projeto_final.qpf / .qsf   # projeto Quartus (pinos do Golden Top)
├── DE10_LITE_Golden_Top.v                # topo: instancia e liga os modulos
├── proposta.md                           # proposta entregue ao professor
├── rtl/                                  # modulos Verilog
│   ├── sync_2ff.v                        # sincronizador de 2 flip-flops
│   └── fsm_sentido.v                     # item 1
└── tb/                                   # testbenches e scripts do ModelSim
    ├── tb_fsm_sentido.v
    └── sim_fsm_sentido.do
```

## Como compilar e simular

- **Quartus Prime 18.1:** abrir `2026_2_LDH_projeto_final.qpf`, compilar (Ctrl+L) e gravar a placa pelo Programmer.
- **ModelSim:** em File > Change Directory, escolher a pasta `tb/` e rodar `do sim_fsm_sentido.do` no console. O testbench imprime `PASS` ou `FAIL` no final.
