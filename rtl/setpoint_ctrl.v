`timescale 1ns/1ps
// ============================================================
// Arquivo  : setpoint_ctrl.v
// Item     : 2 - Ajuste do setpoint do PWM
// Autor    : Luis
// Descricao: Ajusta o setpoint do PWM de 0 a 100 % em passos de
//            5 % pelos botoes da placa (ativos em 0):
//              KEY1 -> aumenta 5 %   KEY0 -> reduz 5 %
//            Cada botao passa por sincronizador de 2 flip-flops,
//            debounce e detector de borda de descida (momento em
//            que o botao e apertado). Segurar o botao conta um
//            unico passo. O valor satura em 0 e em 100. Se os dois
//            botoes forem detectados no mesmo ciclo, nada muda.
// Portas   : clk        - clock de 50 MHz
//            rst        - reset sincrono, ativo em 1 (duty = 0)
//            key_up_n   - KEY1 cru, ativo em 0
//            key_down_n - KEY0 cru, ativo em 0
//            duty       - setpoint 0..100 %
//            ajuste     - pulso de 1 ciclo a cada toque valido
// ============================================================
module setpoint_ctrl #(
    parameter DEBOUNCE_CICLOS = 500_000   // 10 ms @ 50 MHz
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       key_up_n,    // KEY1 cru, ativo em 0
    input  wire       key_down_n,  // KEY0 cru, ativo em 0
    output reg  [6:0] duty,        // setpoint 0..100 %, passo 5, satura nos limites
    output wire       ajuste       // pulso de 1 ciclo a cada toque valido
);

    // --------------------------------------------------------
    // Constantes
    // --------------------------------------------------------
    localparam [6:0] PASSO    = 7'd5;     // passo do setpoint (%)
    localparam [6:0] DUTY_MAX = 7'd100;   // limite superior (%)
    localparam [6:0] DUTY_MIN = 7'd0;     // limite inferior (%)

    // --------------------------------------------------------
    // Sincronizacao dos botoes (bit 1 = KEY1, bit 0 = KEY0)
    // --------------------------------------------------------
    wire [1:0] key_sync;

    sync_2ff #(.WIDTH(2)) u_sync_keys (
        .clk (clk),
        .d   ({key_up_n, key_down_n}),
        .q   (key_sync)
    );

    // --------------------------------------------------------
    // Debounce de cada botao (repouso em 1)
    // --------------------------------------------------------
    wire up_db;                         // KEY1 filtrado (0 = apertado)
    wire down_db;                       // KEY0 filtrado (0 = apertado)

    debounce #(.CICLOS(DEBOUNCE_CICLOS), .VALOR_RESET(1'b1)) u_db_up (
        .clk (clk),
        .rst (rst),
        .d   (key_sync[1]),
        .q   (up_db)
    );

    debounce #(.CICLOS(DEBOUNCE_CICLOS), .VALOR_RESET(1'b1)) u_db_down (
        .clk (clk),
        .rst (rst),
        .d   (key_sync[0]),
        .q   (down_db)
    );

    // --------------------------------------------------------
    // Detector de borda de descida (1 -> 0 = botao apertado)
    // --------------------------------------------------------
    reg  up_db_ant;                     // valor no ciclo anterior
    reg  down_db_ant;
    wire up_press;                      // pulso de 1 ciclo ao apertar KEY1
    wire down_press;                    // pulso de 1 ciclo ao apertar KEY0

    always @(posedge clk) begin
        if (rst) begin
            up_db_ant   <= 1'b1;
            down_db_ant <= 1'b1;
        end else begin
            up_db_ant   <= up_db;
            down_db_ant <= down_db;
        end
    end

    assign up_press   = up_db_ant   & ~up_db;
    assign down_press = down_db_ant & ~down_db;

    // --------------------------------------------------------
    // Registrador do setpoint com saturacao
    // --------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            duty <= DUTY_MIN;
        end else if (up_press && !down_press) begin
            if (duty >= DUTY_MAX - PASSO)
                duty <= DUTY_MAX;
            else
                duty <= duty + PASSO;
        end else if (down_press && !up_press) begin
            if (duty <= DUTY_MIN + PASSO)
                duty <= DUTY_MIN;
            else
                duty <= duty - PASSO;
        end
    end

    assign ajuste = up_press | down_press;

endmodule
