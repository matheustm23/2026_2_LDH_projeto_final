`timescale 1ns/1ps
// ============================================================
// Arquivo  : debounce.v
// Item     : 2 - Ajuste do setpoint (modulo reutilizavel)
// Autor    : Luis
// Descricao: Filtro de debounce. A saida q so copia a entrada d
//            depois que d fica estavel, diferente de q, por
//            CICLOS ciclos seguidos. Qualquer repique menor que
//            esse tempo e ignorado. A entrada ja deve estar
//            sincronizada (sync_2ff).
// Portas   : clk - clock de 50 MHz
//            rst - reset sincrono, ativo em 1
//            d   - entrada sincronizada
//            q   - saida filtrada
// ============================================================
module debounce #(
    parameter CICLOS      = 500_000,    // tempo de estabilidade: 10 ms @ 50 MHz
    parameter VALOR_RESET = 1'b1        // nivel de repouso (botao ativo em 0 -> 1)
)(
    input  wire clk,
    input  wire rst,
    input  wire d,                      // entrada sincronizada
    output reg  q                       // saida sem repique
);

    // Largura do contador: precisa guardar ate CICLOS
    localparam CNT_W = $clog2(CICLOS + 1);
    localparam [CNT_W-1:0] ULTIMO = CICLOS - 1;   // ultimo ciclo da contagem

    reg [CNT_W-1:0] cnt;                // tempo que d esta diferente de q

    always @(posedge clk) begin
        if (rst) begin
            q   <= VALOR_RESET;
            cnt <= {CNT_W{1'b0}};
        end else if (d == q) begin
            cnt <= {CNT_W{1'b0}};       // entrada igual a saida: zera a contagem
        end else if (cnt == ULTIMO) begin
            q   <= d;                   // ficou estavel o tempo todo: aceita
            cnt <= {CNT_W{1'b0}};
        end else begin
            cnt <= cnt + 1'b1;
        end
    end

endmodule
