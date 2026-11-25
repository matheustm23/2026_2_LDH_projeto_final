`timescale 1ns/1ps
// ============================================================
// Arquivo  : tb_encoder_x4.v
// Item     : 4 - Leitura do encoder
// Autor    : Luis
// Descricao: Testbench autoverificavel do encoder_x4. Gera os
//            sinais de quadratura A/B como o encoder do motor e
//            confere a contagem. Usa filtro curto (FILTRO_CICLOS =
//            4) para simular rapido. Dois DUTs recebem os mesmos
//            sinais: um normal e um com INVERTE = 1. Testes:
//              1) estado apos o reset (pos = 0, nenhum passo)
//              2) 100 transicoes no sentido horario -> pos = +100
//              3) 40 transicoes no sentido anti-horario -> pos = 60
//              4) 11 ciclos completos de quadratura = 44 contagens
//                 (uma volta do eixo do motor: 11 PPR x 4)
//              5) pulsos de ruido menores que o filtro sao ignorados
//              6) repique em uma borda conta um passo so
//              7) mudanca dos dois canais juntos e ignorada
//              8) velocidade alta (borda a cada 7 ciclos)
//              9) reset com A = 1 e B = 0: nenhum passo falso
//             10) DUT com INVERTE = 1 conta ao contrario
//            Verifica tambem, a cada passo, que pos muda de +-1 de
//            acordo com dir_enc e que step dura 1 ciclo.
// ============================================================
module tb_encoder_x4;

    localparam T_CLK  = 20;             // periodo de 20 ns = 50 MHz
    localparam FILTRO = 4;              // filtro curto para simulacao
    localparam INTERV = 20;             // ciclos entre bordas (padrao)

    // --------------------------------------------------------
    // Sinais
    // --------------------------------------------------------
    reg                clk   = 1'b0;
    reg                rst   = 1'b1;
    reg                enc_a = 1'b0;
    reg                enc_b = 1'b0;
    wire               step,     step_inv;
    wire               dir_enc,  dir_inv;
    wire signed [31:0] pos,      pos_inv;

    integer erros  = 0;
    integer passos = 0;                 // pulsos de step contados
    integer fase   = 0;                 // fase atual da quadratura (0..3)
    integer i;
    integer pos_antes, passos_antes;

    reg                step_ant = 1'b0;
    reg                checa    = 1'b0;
    reg signed [31:0]  pos_ref;

    encoder_x4 #(.FILTRO_CICLOS(FILTRO), .INVERTE(1'b0)) dut (
        .clk     (clk),
        .rst     (rst),
        .enc_a   (enc_a),
        .enc_b   (enc_b),
        .step    (step),
        .dir_enc (dir_enc),
        .pos     (pos)
    );

    encoder_x4 #(.FILTRO_CICLOS(FILTRO), .INVERTE(1'b1)) dut_inv (
        .clk     (clk),
        .rst     (rst),
        .enc_a   (enc_a),
        .enc_b   (enc_b),
        .step    (step_inv),
        .dir_enc (dir_inv),
        .pos     (pos_inv)
    );

    // Clock de 50 MHz
    always #(T_CLK/2) clk = ~clk;

    // --------------------------------------------------------
    // Verificacao continua (amostra na borda de descida)
    // --------------------------------------------------------
    always @(negedge clk) begin
        if (!rst) begin
            // a cada passo, pos deve mudar de +-1 no ciclo seguinte
            if (checa) begin
                if ((dir_enc === 1'b1 && pos !== pos_ref + 1) ||
                    (dir_enc === 1'b0 && pos !== pos_ref - 1)) begin
                    $display("FAIL [%0d ns]: pos nao mudou de +-1 conforme dir_enc", $time);
                    erros = erros + 1;
                end
                checa = 1'b0;
            end
            if (step === 1'b1) begin
                passos  = passos + 1;
                pos_ref = pos;
                checa   = 1'b1;
                if (step_ant === 1'b1) begin
                    $display("FAIL [%0d ns]: step ficou em 1 por mais de um ciclo", $time);
                    erros = erros + 1;
                end
            end
            step_ant = step;
        end
    end

    // --------------------------------------------------------
    // Tarefas auxiliares
    // --------------------------------------------------------
    task verifica;
        input        cond;
        input [8*72-1:0] msg;
        begin
            if (cond !== 1'b1) begin
                $display("FAIL [%0d ns]: %0s (pos = %0d)", $time, msg, pos);
                erros = erros + 1;
            end else begin
                $display("ok   [%0d ns]: %0s (pos = %0d)", $time, msg, pos);
            end
        end
    endtask

    // Aplica nos canais o nivel {A,B} de uma fase da quadratura
    // fase: 0 = 00, 1 = 10, 2 = 11, 3 = 01 (ordem do sentido horario)
    task aplica_fase;
        input integer f;
        begin
            case (f)
                0: begin enc_a = 1'b0; enc_b = 1'b0; end
                1: begin enc_a = 1'b1; enc_b = 1'b0; end
                2: begin enc_a = 1'b1; enc_b = 1'b1; end
                default: begin enc_a = 1'b0; enc_b = 1'b1; end
            endcase
        end
    endtask

    // Gira n transicoes: sentido 1 = horario, 0 = anti-horario
    task gira;
        input         sentido;
        input integer n;
        input integer intervalo;
        integer j;
        begin
            for (j = 0; j < n; j = j + 1) begin
                if (sentido) fase = (fase + 1) % 4;
                else         fase = (fase + 3) % 4;
                aplica_fase(fase);
                repeat (intervalo) @(negedge clk);
            end
        end
    endtask

    // --------------------------------------------------------
    // Sequencia de testes
    // --------------------------------------------------------
    initial begin
        $display("=== tb_encoder_x4 (FILTRO_CICLOS = %0d) ===", FILTRO);

        // 1) Reset com os canais em 00
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (20) @(negedge clk);
        verifica(pos == 0 && passos == 0, "T1: apos reset pos = 0 e nenhum passo");

        // 2) 100 transicoes no sentido horario
        gira(1'b1, 100, INTERV);
        verifica(pos == 100,      "T2: 100 transicoes horario -> pos = +100");
        verifica(passos == 100,   "T2: 100 pulsos de step");
        verifica(dir_enc === 1'b1, "T2: dir_enc = 1 (horario)");

        // 3) 40 transicoes no sentido anti-horario
        passos = 0;
        gira(1'b0, 40, INTERV);
        verifica(pos == 60,       "T3: 40 transicoes anti-horario -> pos = 60");
        verifica(passos == 40,    "T3: 40 pulsos de step");
        verifica(dir_enc === 1'b0, "T3: dir_enc = 0 (anti-horario)");

        // 4) Uma volta do eixo do motor: 11 ciclos de quadratura
        pos_antes = pos;
        gira(1'b1, 11*4, INTERV);
        verifica(pos - pos_antes == 44, "T4: 11 ciclos de quadratura = 44 contagens (1 volta do motor)");

        // 5) Ruido menor que o filtro nos dois canais
        pos_antes = pos; passos_antes = passos;
        enc_a = ~enc_a; repeat (FILTRO/2) @(negedge clk); enc_a = ~enc_a;
        repeat (INTERV) @(negedge clk);
        enc_b = ~enc_b; repeat (FILTRO/2) @(negedge clk); enc_b = ~enc_b;
        repeat (INTERV) @(negedge clk);
        verifica(pos == pos_antes && passos == passos_antes, "T5: pulsos de ruido curtos sao ignorados");

        // 6) Repique na borda: o canal oscila antes de firmar
        pos_antes = pos;
        fase = (fase + 1) % 4;          // proxima fase no sentido horario
        for (i = 0; i < 4; i = i + 1) begin
            aplica_fase(fase);           repeat (FILTRO/2) @(negedge clk);
            aplica_fase((fase + 3) % 4); repeat (FILTRO/2) @(negedge clk);
        end
        aplica_fase(fase);
        repeat (INTERV) @(negedge clk);
        verifica(pos - pos_antes == 1, "T6: repique na borda conta um passo so");

        // 7) Dois canais mudando juntos (transicao invalida)
        pos_antes = pos; passos_antes = passos;
        fase = (fase + 2) % 4;          // pula uma fase: A e B mudam juntos
        aplica_fase(fase);
        repeat (INTERV) @(negedge clk);
        verifica(pos == pos_antes && passos == passos_antes, "T7: mudanca dos dois canais juntos e ignorada");
        pos_antes = pos;
        gira(1'b1, 8, INTERV);
        verifica(pos - pos_antes == 8,  "T7: continua contando depois da transicao invalida");

        // 8) Velocidade alta: borda a cada FILTRO + 3 ciclos
        pos_antes = pos;
        gira(1'b1, 200, FILTRO + 3);
        repeat (INTERV) @(negedge clk);
        verifica(pos - pos_antes == 200, "T8: 200 transicoes rapidas contadas");

        // 9) Reset com A = 1 e B = 0 (fase 1): nenhum passo falso
        fase = 1;
        aplica_fase(fase);
        repeat (INTERV) @(negedge clk);
        rst = 1'b1;
        repeat (3) @(negedge clk);
        verifica(pos == 0,        "T9: reset zera pos");
        passos = 0;
        rst = 1'b0;
        repeat (50) @(negedge clk);
        verifica(pos == 0 && passos == 0, "T9: sem passo falso ao sair do reset com A = 1, B = 0");
        gira(1'b1, 4, INTERV);
        verifica(pos == 4,        "T9: conta normalmente depois do reset");

        // 10) INVERTE = 1: o mesmo giro conta ao contrario
        verifica(pos_inv == -4 && dir_inv === 1'b0, "T10: DUT com INVERTE = 1 conta -4");

        // Resultado
        $display("==================================================");
        if (erros == 0)
            $display("PASS: todos os testes do encoder_x4 passaram");
        else
            $display("FAIL: %0d erro(s) encontrado(s)", erros);
        $display("==================================================");
        $finish;
    end

    // Protecao contra simulacao travada
    initial begin
        #(T_CLK * 100000);
        $display("FAIL: timeout da simulacao");
        $finish;
    end

endmodule
