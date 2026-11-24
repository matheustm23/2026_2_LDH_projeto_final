Propostas para o projeto final da UC de linguagem de descrição de hardware
Integrantes: Matheus e Luís
Ideia 1: Acionamento bidirecional e medição de velocidade de motor CC com encoder em FPGA
Materiais utilizados:
1) Motor JGB37-520 de 12 V com encoder,
2) Ponte H L298N,
3) Fonte externa de 12 V,
4) FPGA DE10Lite
Obs: estamos usando esse motor e ponte H na UC de Atividade de Extensão 2.
Descrição das funcionalidades:
1) Inversão do sentido de rotação por uma chave da placa (SW0). Ao inverter, uma FSM zera o
PWM, aguarda um tempo (ex.: 0,5 s), e religa o PWM.
2) Ajuste do setpoint do PWM de 0 a 100 % em passos de 5 % por duas chaves da placa, uma para
aumentar e outra para reduzir, com debounce e detecção de borda.
3) Gerador de PWM para o pino ENA da ponte H L298N.
4) Leitura do encoder com sincronizador de 2 flip-flops e decodificação x4.
5) Medição de velocidade por contagem de pulsos com conversão para RPM
6) Exibição nos displays de 7 segmentos do RPM medido (com uma casa decimal) e do setpoint em
%, LEDs indicam o sentido de rotação.
