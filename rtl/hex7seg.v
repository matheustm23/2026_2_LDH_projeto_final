`timescale 1ns/1ps
// ============================================================
// Arquivo  : hex7seg.v
// Item     : 4 - Leitura do encoder (reutilizado no item 6)
// Autor    : Luis
// Descricao: Decodificador de um digito hexadecimal (0..F) para
//            display de 7 segmentos da DE10-Lite (segmentos ativos
//            em 0). Ordem dos bits igual a dos pinos HEXn[6:0]:
//              seg[0] = a, seg[1] = b, ..., seg[6] = g
//                  a
//                f   b
//                  g
//                e   c
//                  d
// Portas   : hex - digito de entrada
//            seg - segmentos (0 = aceso)
// ============================================================
module hex7seg (
    input  wire [3:0] hex,              // digito 0..F
    output reg  [6:0] seg               // {g,f,e,d,c,b,a}, ativos em 0
);

    always @(*) begin
        case (hex)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;     // b minusculo
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;     // d minusculo
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;  // apagado
        endcase
    end

endmodule
