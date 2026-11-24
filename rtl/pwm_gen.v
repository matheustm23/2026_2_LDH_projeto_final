`timescale 1ns/1ps
// ============================================================
// Arquivo  : pwm_gen.v
// Item     : 3 - Gerador de PWM para o ENA da L298N
// Autor    : Matheus
// Descricao: Gera um PWM de frequencia F_PWM com resolucao de
//            1 % (100 passos por periodo). Um prescaler divide o
//            clock ate a frequencia de passo (F_PWM x 100) e um
//            contador de 0 a 99 forma o periodo. A saida fica em 1
//            enquanto o passo for menor que o duty.
//            - duty = 0     -> saida sempre 0
//            - duty >= 100  -> saida sempre 1
//            - o duty e capturado so no inicio de cada periodo,
//              entao mudar o setpoint no meio nao gera glitch
//            - en = 0 zera a saida no ciclo seguinte e segura o
//              periodo no inicio (pausa da troca de sentido do
//              item 1); quando en volta a 1, comeca um periodo
//              novo e inteiro com o duty atual
//            Com os valores padrao: 50 MHz / (1 kHz x 100) = 500
//            ciclos por passo, periodo de 50.000 ciclos = 1 ms.
// Portas   : clk  - clock de 50 MHz
//            rst  - reset sincrono, ativo em 1
//            duty - setpoint 0..100 % (item 2)
//            en   - habilitacao (pwm_en do item 1)
//            pwm  - saida para o ENA da L298N
// ============================================================
module pwm_gen #(
    parameter CLK_HZ = 50_000_000,
    parameter F_PWM  = 1_000          // Hz (sugestao inicial)
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [6:0] duty,   // 0..100 %
    input  wire       en,     // 0 -> pwm = 0 (vem do pwm_en do item 1)
    output reg        pwm     // ENA da L298N
);

    // --------------------------------------------------------
    // Constantes
    // --------------------------------------------------------
    localparam       PASSOS   = 100;                        // passos por periodo (1 %)
    localparam integer DIV    = CLK_HZ / (F_PWM * PASSOS);  // ciclos de clock por passo
    localparam       DIV_W    = $clog2(DIV + 1);
    localparam [DIV_W-1:0] DIV_ULT  = DIV[DIV_W-1:0] - 1'b1;   // ultimo ciclo do passo
    localparam [6:0] PASSO_ULT = PASSOS - 1;                // ultimo passo do periodo (99)
    localparam [6:0] DUTY_MAX  = 7'd100;

    // --------------------------------------------------------
    // Sinais internos
    // --------------------------------------------------------
    reg  [DIV_W-1:0] div_cnt;           // prescaler
    reg  [6:0]       passo;             // posicao dentro do periodo (0..99)
    reg  [6:0]       duty_reg;          // duty capturado no inicio do periodo
    wire             tick;              // fim de um passo
    wire             fim_periodo;       // fim do periodo (ultimo ciclo)

    assign tick        = (div_cnt == DIV_ULT);
    assign fim_periodo = tick && (passo == PASSO_ULT);

    // --------------------------------------------------------
    // Prescaler: gera um tick a cada DIV ciclos
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst || !en || tick)
            div_cnt <= {DIV_W{1'b0}};
        else
            div_cnt <= div_cnt + 1'b1;
    end

    // --------------------------------------------------------
    // Contador de passos (0..99) e captura do duty
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            passo    <= 7'd0;
            duty_reg <= 7'd0;
        end else if (!en || fim_periodo) begin  // desabilitado ou fim do periodo:
                                                // volta ao inicio e captura o duty
            passo    <= 7'd0;
            duty_reg <= (duty > DUTY_MAX) ? DUTY_MAX : duty;   // satura em 100
        end else if (tick) begin
            passo    <= passo + 1'b1;
        end
    end

    // --------------------------------------------------------
    // Saida registrada (sem glitch)
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            pwm <= 1'b0;
        else
            pwm <= en && (passo < duty_reg);
    end

endmodule
