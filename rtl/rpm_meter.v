`timescale 1ns/1ps
// ============================================================
// Arquivo  : rpm_meter.v
// Item     : 5 - Medicao de velocidade em RPM
// Autor    : Matheus
// Descricao: Mede a velocidade do eixo de saida contando os
//            pulsos step do encoder_x4 dentro de uma janela de
//            tempo fixa. A janela e escolhida para que a propria
//            contagem ja seja o RPM x 10, sem divisao no hardware:
//              RPM = (contagens / CPR_SAIDA) / T x 60
//              com T = 600 / CPR_SAIDA s -> contagens = RPM x 10
//            Com CPR_SAIDA = 3960 (44 contagens por volta do motor
//            x reducao 1:90): T = 0,1515 s (7.575.600 ciclos de
//            50 MHz), resolucao de 0,1 RPM e cerca de 6,6
//            atualizacoes por segundo.
//            Mede o modulo da velocidade (o sentido vem da SW0).
//            O resultado satura em 9999 (999,9 RPM).
//            CPR_SAIDA = 3960 e provisorio: confirmar com a
//            calibracao do encoder (README) e ajustar no topo.
// Portas   : clk       - clock de 50 MHz
//            rst       - reset sincrono, ativo em 1
//            step      - pulso de 1 ciclo por borda do encoder (item 4)
//            rpm_x10   - RPM x 10 (523 = 52,3 RPM)
//            rpm_valid - pulso de 1 ciclo quando rpm_x10 atualiza
// ============================================================
module rpm_meter #(
    parameter CLK_HZ    = 50_000_000,
    parameter CPR_SAIDA = 3960   // contagens x4 por volta do eixo de saida (CONFIRMAR na calibracao)
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        step,       // do encoder_x4
    output reg  [13:0] rpm_x10,    // RPM x 10 (523 = 52,3 RPM), saturar em 9999
    output reg         rpm_valid   // pulso de 1 ciclo quando rpm_x10 atualiza
);

    // --------------------------------------------------------
    // Constantes
    // --------------------------------------------------------
    // Janela em ciclos de clock. A divisao vem antes da
    // multiplicacao para nao estourar os 32 bits dos parametros.
    localparam integer JANELA = (CLK_HZ / CPR_SAIDA) * 600;
    localparam         JW     = $clog2(JANELA + 1);
    localparam [JW-1:0] J_ULT = JANELA[JW-1:0] - 1'b1;   // ultimo ciclo da janela
    localparam [13:0]  RPM_MAX = 14'd9999;                // limite de 999,9 RPM

    // --------------------------------------------------------
    // Sinais internos
    // --------------------------------------------------------
    reg  [JW-1:0] t_cnt;                // tempo dentro da janela
    reg  [13:0]   pulsos;               // pulsos contados na janela atual
    wire          fim_janela;
    wire [13:0]   pulsos_final;         // contagem incluindo o ultimo ciclo

    assign fim_janela   = (t_cnt == J_ULT);
    assign pulsos_final = (step && pulsos != RPM_MAX) ? pulsos + 1'b1 : pulsos;

    // --------------------------------------------------------
    // Base de tempo da janela
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst || fim_janela)
            t_cnt <= {JW{1'b0}};
        else
            t_cnt <= t_cnt + 1'b1;
    end

    // --------------------------------------------------------
    // Contagem de pulsos e atualizacao do resultado
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            pulsos    <= 14'd0;
            rpm_x10   <= 14'd0;
            rpm_valid <= 1'b0;
        end else if (fim_janela) begin
            rpm_x10   <= pulsos_final;  // fecha a janela (conta o step do ultimo ciclo)
            pulsos    <= 14'd0;
            rpm_valid <= 1'b1;
        end else begin
            pulsos    <= pulsos_final;  // satura em 9999
            rpm_valid <= 1'b0;
        end
    end

endmodule
