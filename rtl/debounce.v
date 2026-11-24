`timescale 1ns/1ps
// Filtro de debounce para uma entrada digital.
// A saida so muda depois que a entrada permanece estavel
// por DEBOUNCE_CICLOS ciclos de clock.
module debounce #(
    parameter DEBOUNCE_CICLOS = 500_000
)(
    input  wire clk,
    input  wire rst,
    input  wire noisy,
    output reg  clean
);
    localparam CNT_W = (DEBOUNCE_CICLOS <= 1) ? 1 : $clog2(DEBOUNCE_CICLOS + 1);
    localparam [CNT_W-1:0] LIMITE = DEBOUNCE_CICLOS - 1;

    reg [CNT_W-1:0] contador;

    always @(posedge clk) begin
        if (rst) begin
            clean     <= 1'b1; // botoes KEY da DE10-Lite sao ativos em nivel baixo
            contador  <= {CNT_W{1'b0}};
        end else if (noisy == clean) begin
            contador <= {CNT_W{1'b0}};
        end else if (contador == LIMITE) begin
            clean    <= noisy;
            contador <= {CNT_W{1'b0}};
        end else begin
            contador <= contador + 1'b1;
        end
    end
endmodule
