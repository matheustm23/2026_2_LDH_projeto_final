`timescale 1ns/1ps
// ============================================================
// Arquivo  : tb_rpm_meter.v
// Item     : 5 - Medicao de velocidade em RPM
// Autor    : Matheus
// Descricao: Testbench autoverificavel do rpm_meter.
//            DUT principal com parametros pequenos (CLK_HZ = 1000,
//            CPR_SAIDA = 100 -> janela de 6000 ciclos) para
//            simular rapido. Um gerador com acumulador de fase
//            produz exatamente RPMx10 pulsos por janela, entao a
//            leitura esperada e exata. Testes:
//              1) apos o reset: rpm_x10 = 0
//              2) sem pulsos: leitura 0, janela de exatamente 6000
//                 ciclos e rpm_valid de 1 ciclo
//              3) 52,3 RPM -> 523 em duas janelas seguidas
//              4) 60,0 / 1,5 / 0,1 RPM -> 600 / 15 / 1
//              5) pulso em todo ciclo -> 6000 (nenhum pulso perdido
//                 na virada da janela)
//              6) mudanca de velocidade no meio da janela: valor
//                 intermediario e depois o valor novo exato
//              7) saturacao em 9999 (segundo DUT, janela maior)
//              8) parametros reais: janela de 7.575.600 ciclos com
//                 CPR 3960 e de 4.058.400 com CPR 7392
//              9) reset no meio zera a leitura
// ============================================================
module tb_rpm_meter;

    localparam T_CLK  = 20;             // periodo de 20 ns
    localparam CLK_HZ = 1000;           // valores pequenos para simulacao
    localparam CPR    = 100;
    localparam JANELA = (CLK_HZ / CPR) * 600;   // 6000 ciclos
    localparam LIMITE = 3 * JANELA;

    // --------------------------------------------------------
    // Sinais
    // --------------------------------------------------------
    reg         clk  = 1'b0;
    reg         rst  = 1'b1;
    reg         step = 1'b0;
    wire [13:0] rpm_x10;
    wire        rpm_valid;

    reg         step_sat = 1'b0;        // DUT de saturacao
    wire [13:0] rpm_sat;
    wire        valid_sat;

    wire [13:0] rpm_r1, rpm_r2;         // DUTs com parametros reais
    wire        val_r1, val_r2;

    integer erros    = 0;
    integer r10_alvo = 0;               // RPM x 10 que o gerador produz
    integer acc      = 0;               // acumulador de fase do gerador
    integer v1, v2, per, k;
    reg     valid_ant = 1'b0;

    rpm_meter #(.CLK_HZ(CLK_HZ), .CPR_SAIDA(CPR)) dut (
        .clk       (clk),
        .rst       (rst),
        .step      (step),
        .rpm_x10   (rpm_x10),
        .rpm_valid (rpm_valid)
    );

    // janela de (2000/100)*600 = 12000 ciclos: com pulso em todo
    // ciclo a contagem passaria de 9999
    rpm_meter #(.CLK_HZ(2000), .CPR_SAIDA(100)) dut_sat (
        .clk       (clk),
        .rst       (rst),
        .step      (step_sat),
        .rpm_x10   (rpm_sat),
        .rpm_valid (valid_sat)
    );

    rpm_meter dut_real1 (                               // 50 MHz, CPR 3960
        .clk (clk), .rst (rst), .step (1'b0), .rpm_x10 (rpm_r1), .rpm_valid (val_r1)
    );

    rpm_meter #(.CPR_SAIDA(7392)) dut_real2 (           // 50 MHz, CPR 7392
        .clk (clk), .rst (rst), .step (1'b0), .rpm_x10 (rpm_r2), .rpm_valid (val_r2)
    );

    // Clock
    always #(T_CLK/2) clk = ~clk;

    // --------------------------------------------------------
    // Gerador de pulsos: exatamente r10_alvo pulsos a cada JANELA
    // ciclos (muda na borda de descida, estavel na de subida)
    // --------------------------------------------------------
    always @(negedge clk) begin
        if (r10_alvo == 0) begin
            step <= 1'b0;
        end else begin
            acc = acc + r10_alvo;
            if (acc >= JANELA) begin
                acc  = acc - JANELA;
                step <= 1'b1;
            end else begin
                step <= 1'b0;
            end
        end
    end

    // rpm_valid deve durar 1 ciclo
    always @(negedge clk) begin
        if (!rst && rpm_valid === 1'b1 && valid_ant === 1'b1) begin
            $display("FAIL [%0d ns]: rpm_valid ficou em 1 por mais de um ciclo", $time);
            erros = erros + 1;
        end
        valid_ant = rpm_valid;
    end

    // --------------------------------------------------------
    // Tarefas auxiliares
    // --------------------------------------------------------
    task verifica;
        input        cond;
        input [8*72-1:0] msg;
        begin
            if (cond !== 1'b1) begin
                $display("FAIL [%0d ns]: %0s (rpm_x10 = %0d)", $time, msg, rpm_x10);
                erros = erros + 1;
            end else begin
                $display("ok   [%0d ns]: %0s (rpm_x10 = %0d)", $time, msg, rpm_x10);
            end
        end
    endtask

    // Espera o proximo rpm_valid e devolve a leitura e quantos
    // ciclos se passaram desde a chamada
    task proxima_janela;
        output integer valor;
        output integer ciclos;
        begin
            ciclos = 0;
            @(negedge clk);
            ciclos = 1;
            while (rpm_valid !== 1'b1 && ciclos < LIMITE) begin
                @(negedge clk);
                ciclos = ciclos + 1;
            end
            if (rpm_valid !== 1'b1) begin
                $display("FAIL [%0d ns]: rpm_valid nao apareceu", $time);
                erros = erros + 1;
            end
            valor = rpm_x10;
        end
    endtask

    // Ajusta a velocidade, descarta a janela parcial e confere
    // duas janelas inteiras
    task mede_velocidade;
        input integer r10;
        begin
            r10_alvo = r10;
            proxima_janela(v1, per);    // janela parcial (mudou no meio)
            proxima_janela(v1, per);
            proxima_janela(v2, per);
            if (v1 == r10 && v2 == r10)
                $display("ok   [%0d ns]: %0d,%0d RPM -> leituras %0d e %0d",
                         $time, r10/10, r10%10, v1, v2);
            else begin
                $display("FAIL [%0d ns]: %0d,%0d RPM -> leituras %0d e %0d (esperado %0d)",
                         $time, r10/10, r10%10, v1, v2, r10);
                erros = erros + 1;
            end
        end
    endtask

    // --------------------------------------------------------
    // Sequencia de testes
    // --------------------------------------------------------
    initial begin
        $display("=== tb_rpm_meter (janela de teste = %0d ciclos) ===", JANELA);

        // 1) Reset
        repeat (5) @(negedge clk);
        verifica(rpm_x10 == 0 && rpm_valid === 1'b0, "T1: apos reset rpm_x10 = 0");
        rst = 1'b0;

        // 2) Sem pulsos: leitura 0 e periodo da janela
        proxima_janela(v1, per);
        proxima_janela(v1, per);
        verifica(v1 == 0,         "T2: sem pulsos -> leitura 0");
        verifica(per == JANELA,   "T2: janela de exatamente 6000 ciclos");

        // 3) e 4) Velocidades conhecidas
        mede_velocidade(523);           // 52,3 RPM
        mede_velocidade(600);           // 60,0 RPM
        mede_velocidade(15);            // 1,5 RPM
        mede_velocidade(1);             // 0,1 RPM

        // 5) Pulso em todo ciclo: nenhum pulso perdido na virada
        mede_velocidade(JANELA);        // 6000

        // 6) Mudanca de velocidade no meio de uma janela
        r10_alvo = 523;
        proxima_janela(v1, per);
        proxima_janela(v1, per);
        repeat (JANELA/2) @(negedge clk);
        r10_alvo = 300;                 // muda no meio da janela
        proxima_janela(v1, per);        // janela misturada
        proxima_janela(v2, per);        // primeira janela inteira com 300
        verifica(v1 > 300 && v1 < 523, "T6: janela da mudanca fica entre 300 e 523");
        verifica(v2 == 300,       "T6: valor novo (300) na primeira janela inteira");

        // 7) Saturacao
        step_sat = 1'b1;                // pulso em todo ciclo no DUT de saturacao
        k = 0;
        while (valid_sat !== 1'b1 && k < 30000) begin @(negedge clk); k = k + 1; end
        @(negedge clk);
        k = 0;
        while (valid_sat !== 1'b1 && k < 30000) begin @(negedge clk); k = k + 1; end
        verifica(rpm_sat == 14'd9999, "T7: contagem acima de 9999 satura em 9999");

        // 8) Parametros reais (janela calculada pelo modulo)
        $display("     T8: janela real com CPR 3960 = %0d ciclos (%0d us)",
                 dut_real1.JANELA, dut_real1.JANELA / 50);
        verifica(dut_real1.JANELA == 7575600, "T8: CPR 3960 -> janela de 7.575.600 ciclos (0,1515 s)");
        verifica(dut_real2.JANELA == 4058400, "T8: CPR 7392 -> janela de 4.058.400 ciclos (0,0812 s)");

        // 9) Reset no meio
        r10_alvo = 523;
        proxima_janela(v1, per);
        proxima_janela(v1, per);
        rst = 1'b1;
        repeat (2) @(negedge clk);
        verifica(rpm_x10 == 0,    "T9: reset zera a leitura");
        rst = 1'b0;

        // Resultado
        $display("==================================================");
        if (erros == 0)
            $display("PASS: todos os testes do rpm_meter passaram");
        else
            $display("FAIL: %0d erro(s) encontrado(s)", erros);
        $display("==================================================");
        $finish;
    end

    // Protecao contra simulacao travada
    initial begin
        #(T_CLK * 400000);
        $display("FAIL: timeout da simulacao");
        $finish;
    end

endmodule
