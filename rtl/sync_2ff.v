`timescale 1ns/1ps
// ============================================================
// Arquivo  : sync_2ff.v
// Item     : 1 - Inversao do sentido de rotacao (modulo compartilhado)
// Autor    : Matheus
// Descricao: Sincronizador de 2 flip-flops para entradas
//            assincronas da placa (chaves, botoes, encoder).
//            Reduz o risco de metaestabilidade antes de o sinal
//            entrar na logica sincrona. Atraso de 2 ciclos.
// Portas   : clk - clock de 50 MHz
//            d   - entrada assincrona (WIDTH bits)
//            q   - saida sincronizada (WIDTH bits)
// ============================================================
module sync_2ff #(
    parameter WIDTH = 1                 // largura do barramento
)(
    input  wire             clk,
    input  wire [WIDTH-1:0] d,          // entrada assincrona
    output wire [WIDTH-1:0] q           // saida sincronizada por 2 flip-flops
);

    reg [WIDTH-1:0] ff1;                // 1o estagio (pode ficar metaestavel)
    reg [WIDTH-1:0] ff2;                // 2o estagio (saida estavel)

    always @(posedge clk) begin
        ff1 <= d;
        ff2 <= ff1;
    end

    assign q = ff2;

endmodule
