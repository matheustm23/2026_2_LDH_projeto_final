`timescale 1ns/1ps
// ===========================================================
// Arquivo  : fsm_sentido.v
// Item     : 1 - Inversao do sentido de rotacao
// Autor    : Matheus
// Descricao: FSM que controla o sentido do motor pela SW0.
//            Ao detectar mudanca na chave, zera o PWM (pwm_en=0),
//            aguarda PAUSA_CICLOS (0,5 s) para o motor perder
//            velocidade, aplica o novo sentido e religa o PWM.
//            Se a chave voltar a posicao original durante a pausa,
//            o sentido nao muda (apenas a pausa acontece).
// Portas   : clk    - clock de 50 MHz
//            rst    - reset sincrono, ativo em 1
//            sw_dir - SW0 cru (1 = horario, 0 = anti-horario)
//            dir    - sentido aplicado ao motor
//            pwm_en - 0 durante a pausa (zera o PWM)
//            troca  - 1 durante a pausa (LEDR2)
//            in1    - L298N IN1 (dir = 1 -> in1 = 1)
//            in2    - L298N IN2 (dir = 1 -> in2 = 0)
// ============================================================
module fsm_sentido #(
    parameter PAUSA_CICLOS = 25_000_000   // 0,5 s @ 50 MHz
)(
    input  wire clk,
    input  wire rst,
    input  wire sw_dir,   // SW0 cru: 1 = horario, 0 = anti-horario
    output reg  dir,      // sentido aplicado ao motor
    output wire pwm_en,   // 0 durante a pausa (zera o PWM)
    output wire troca,    // 1 durante a pausa (LEDR2)
    output wire in1,      // L298N IN1: dir = 1 -> in1 = 1, in2 = 0
    output wire in2       // L298N IN2
);

    // --------------------------------------------------------
    // Estados da FSM
    // --------------------------------------------------------
    localparam RODANDO = 1'b0;          // motor ligado no sentido dir
    localparam PAUSA   = 1'b1;          // PWM zerado, contando a pausa

    // Largura do contador: precisa guardar ate PAUSA_CICLOS
    localparam CNT_W = $clog2(PAUSA_CICLOS + 1);
    localparam [CNT_W-1:0] ULTIMO = PAUSA_CICLOS - 1;   // ultimo ciclo da pausa

    // --------------------------------------------------------
    // Sincronizacao da chave SW0
    // --------------------------------------------------------
    wire sw_sync;

    sync_2ff #(.WIDTH(1)) u_sync_sw (
        .clk (clk),
        .d   (sw_dir),
        .q   (sw_sync)
    );

    // --------------------------------------------------------
    // Sinais internos
    // --------------------------------------------------------
    reg             estado;
    reg             prox_estado;
    reg [CNT_W-1:0] cnt;                // contador da pausa
    wire            fim_pausa;

    assign fim_pausa = (cnt == ULTIMO);

    // --------------------------------------------------------
    // Registrador de estado
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            estado <= RODANDO;
        else
            estado <= prox_estado;
    end

    // --------------------------------------------------------
    // Logica de proximo estado
    // --------------------------------------------------------
    always @(*) begin
        prox_estado = estado;           // valor padrao: permanece
        case (estado)
            RODANDO: if (sw_sync != dir) prox_estado = PAUSA;
            PAUSA:   if (fim_pausa)      prox_estado = RODANDO;
            default:                     prox_estado = RODANDO;
        endcase
    end

    // --------------------------------------------------------
    // Contador da pausa: conta somente no estado PAUSA
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst || estado != PAUSA)
            cnt <= {CNT_W{1'b0}};
        else
            cnt <= cnt + 1'b1;
    end

    // --------------------------------------------------------
    // Sentido aplicado: atualizado no ultimo ciclo da pausa
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            dir <= 1'b0;
        else if (estado == PAUSA && fim_pausa)
            dir <= sw_sync;
    end

    // --------------------------------------------------------
    // Saidas (Moore)
    // --------------------------------------------------------
    assign pwm_en = (estado == RODANDO);
    assign troca  = (estado == PAUSA);
    assign in1    = dir;
    assign in2    = ~dir;

endmodule
