`timescale 1ns/1ps
// ============================================================
// Arquivo  : tb_hex7seg.v
// Item     : 4 - Leitura do encoder (decodificador de display)
// Autor    : Luis
// Descricao: Testbench autoverificavel do hex7seg. Para cada
//            digito 0..F, a lista de segmentos acesos esperada e
//            escrita como texto ("abcdef" para o 0) e convertida
//            para o padrao ativo em 0, sem copiar a tabela do
//            modulo.
// ============================================================
module tb_hex7seg;

    reg  [3:0] hex;
    wire [6:0] seg;

    integer erros = 0;
    integer d, k;
    reg [8*7-1:0] acesos;               // ate 7 letras
    reg [6:0]     esperado;
    reg [7:0]     letra;

    hex7seg dut (
        .hex (hex),
        .seg (seg)
    );

    // Segmentos acesos de cada digito
    function [8*7-1:0] segmentos;
        input [3:0] dig;
        begin
            case (dig)
                4'h0: segmentos = "abcdef";
                4'h1: segmentos = "bc";
                4'h2: segmentos = "abdeg";
                4'h3: segmentos = "abcdg";
                4'h4: segmentos = "bcfg";
                4'h5: segmentos = "acdfg";
                4'h6: segmentos = "acdefg";
                4'h7: segmentos = "abc";
                4'h8: segmentos = "abcdefg";
                4'h9: segmentos = "abcdfg";
                4'hA: segmentos = "abcefg";
                4'hB: segmentos = "cdefg";
                4'hC: segmentos = "adef";
                4'hD: segmentos = "bcdeg";
                4'hE: segmentos = "adefg";
                default: segmentos = "aefg";   // F
            endcase
        end
    endfunction

    initial begin
        $display("=== tb_hex7seg ===");
        for (d = 0; d < 16; d = d + 1) begin
            hex = d;
            #10;
            // converte a lista de letras em padrao ativo em 0
            acesos   = segmentos(d);
            esperado = 7'b1111111;
            for (k = 0; k < 7; k = k + 1) begin
                letra = acesos[8*k +: 8];
                if (letra >= "a" && letra <= "g")
                    esperado[letra - "a"] = 1'b0;
            end
            if (seg !== esperado) begin
                $display("FAIL: digito %0h -> seg = %b (esperado %b)", d, seg, esperado);
                erros = erros + 1;
            end else begin
                $display("ok   : digito %0h -> seg = %b", d, seg);
            end
        end

        $display("==================================================");
        if (erros == 0)
            $display("PASS: todos os testes do hex7seg passaram");
        else
            $display("FAIL: %0d erro(s) encontrado(s)", erros);
        $display("==================================================");
        $finish;
    end

endmodule
