`timescale 1ns/1ps
// ============================================================
// Arquivo  : tb_pwm_gen.v
// Item     : 3 - Gerador de PWM para o ENA da L298N
// Autor    : Matheus
// Descricao: Testbench autoverificavel do pwm_gen.
//            DUT principal com parametros pequenos (CLK_HZ = 3000,
//            F_PWM = 10 -> 3 ciclos por passo, periodo de 300
//            ciclos) para simular rapido. Testes:
//              1) saida em 0 durante e apos o reset
//              2) duty 5, 37, 50 e 95: tempo em 1 e periodo exatos
//              3) duty 0 -> sempre 0; duty 100 -> sempre 1
//              4) duty acima de 100 (120) tratado como 100
//              5) aumentar o duty no meio do periodo nao gera glitch
//              6) reduzir o duty no meio do periodo nao corta o pulso
//              7) en = 0 zera a saida e en = 1 retoma
//              8) DUT com os parametros reais: 1 kHz @ 50 MHz
//                 (periodo de 50.000 ciclos, duty 50 = 25.000)
// ============================================================
module tb_pwm_gen;

    localparam T_CLK  = 20;             // periodo de 20 ns = 50 MHz
    localparam CLK_HZ = 3000;           // valores pequenos para simulacao
    localparam F_PWM  = 10;
    localparam DIV    = CLK_HZ / (F_PWM * 100);   // 3 ciclos por passo
    localparam P      = DIV * 100;                // 300 ciclos por periodo
    localparam LIMITE = 4 * P;                    // limite das esperas

    // --------------------------------------------------------
    // Sinais
    // --------------------------------------------------------
    reg        clk  = 1'b0;
    reg        rst  = 1'b1;
    reg  [6:0] duty = 7'd0;
    reg        en   = 1'b1;
    wire       pwm;

    reg  [6:0] duty_real = 7'd50;       // DUT com parametros reais
    wire       pwm_real;

    integer erros = 0;
    integer alto, periodo, k, i;
    integer lista [0:3];
    reg     teve_1, teve_0;

    // DUT principal (parametros pequenos)
    pwm_gen #(.CLK_HZ(CLK_HZ), .F_PWM(F_PWM)) dut (
        .clk  (clk),
        .rst  (rst),
        .duty (duty),
        .en   (en),
        .pwm  (pwm)
    );

    // DUT com os parametros reais (50 MHz, 1 kHz)
    pwm_gen dut_real (
        .clk  (clk),
        .rst  (rst),
        .duty (duty_real),
        .en   (1'b1),
        .pwm  (pwm_real)
    );

    // Clock de 50 MHz
    always #(T_CLK/2) clk = ~clk;

    // --------------------------------------------------------
    // Tarefas auxiliares (amostragem na borda de descida)
    // --------------------------------------------------------
    task verifica;
        input        cond;
        input [8*64-1:0] msg;
        begin
            if (cond !== 1'b1) begin
                $display("FAIL [%0d ns]: %0s", $time, msg);
                erros = erros + 1;
            end else begin
                $display("ok   [%0d ns]: %0s", $time, msg);
            end
        end
    endtask

    // Espera a proxima borda de subida do pwm. Ao sair, a amostra
    // atual e a primeira em 1 do periodo.
    task espera_subida;
        integer t;
        reg     ant;
        reg     achou;
        begin
            achou = 1'b0;
            t     = 0;
            ant   = pwm;
            while (!achou && t < LIMITE) begin
                @(negedge clk);
                t = t + 1;
                if (ant === 1'b0 && pwm === 1'b1) achou = 1'b1;
                ant = pwm;
            end
            if (!achou) begin
                $display("FAIL [%0d ns]: borda de subida do pwm nao encontrada", $time);
                erros = erros + 1;
            end
        end
    endtask

    // Chamar logo apos espera_subida: mede quantos ciclos o pwm
    // fica em 1 e o periodo ate a proxima subida.
    task mede;
        output integer t_alto;
        output integer t_periodo;
        begin
            t_alto    = 0;
            t_periodo = 0;
            while (pwm === 1'b1 && t_periodo < LIMITE) begin
                t_alto    = t_alto + 1;
                t_periodo = t_periodo + 1;
                @(negedge clk);
            end
            while (pwm === 1'b0 && t_periodo < LIMITE) begin
                t_periodo = t_periodo + 1;
                @(negedge clk);
            end
        end
    endtask

    // Observa o pwm por n ciclos e registra se apareceu 0 e/ou 1
    task observa;
        input integer n;
        integer c;
        begin
            teve_0 = 1'b0;
            teve_1 = 1'b0;
            for (c = 0; c < n; c = c + 1) begin
                @(negedge clk);
                if (pwm === 1'b1) teve_1 = 1'b1;
                if (pwm === 1'b0) teve_0 = 1'b1;
            end
        end
    endtask

    // --------------------------------------------------------
    // Sequencia de testes
    // --------------------------------------------------------
    initial begin
        $display("=== tb_pwm_gen (DIV = %0d ciclos por passo, periodo = %0d ciclos) ===", DIV, P);
        lista[0] = 5; lista[1] = 37; lista[2] = 50; lista[3] = 95;

        // 1) Reset
        duty = 7'd50;
        repeat (5) @(negedge clk);
        verifica(pwm === 1'b0, "T1: pwm = 0 durante o reset");
        rst = 1'b0;

        // 2) Duty intermediarios
        for (i = 0; i < 4; i = i + 1) begin
            duty = lista[i];
            repeat (2*P) @(negedge clk);
            espera_subida;
            mede(alto, periodo);
            if (alto == lista[i]*DIV && periodo == P)
                $display("ok   [%0d ns]: T2: duty %0d -> %0d ciclos em 1 de %0d", $time, lista[i], alto, periodo);
            else begin
                $display("FAIL [%0d ns]: T2: duty %0d -> %0d ciclos em 1 de %0d (esperado %0d de %0d)",
                         $time, lista[i], alto, periodo, lista[i]*DIV, P);
                erros = erros + 1;
            end
        end

        // 3) Extremos
        duty = 7'd0;
        repeat (2*P) @(negedge clk);
        observa(2*P);
        verifica(!teve_1,         "T3: duty 0 -> pwm sempre 0");
        duty = 7'd100;
        repeat (2*P) @(negedge clk);
        observa(2*P);
        verifica(!teve_0,         "T3: duty 100 -> pwm sempre 1");

        // 4) Acima de 100
        duty = 7'd0;
        repeat (2*P) @(negedge clk);
        duty = 7'd120;
        repeat (2*P) @(negedge clk);
        observa(2*P);
        verifica(!teve_0,         "T4: duty 120 tratado como 100 (sempre 1)");

        // 5) Aumentar no meio do periodo (saida ja em 0): sem glitch
        duty = 7'd20;
        repeat (2*P) @(negedge clk);
        espera_subida;                  // indice 0 = primeira amostra em 1
        k = 0;
        repeat (30*DIV) begin @(negedge clk); k = k + 1; end   // passo ~30: pwm em 0
        duty = 7'd80;
        while (pwm !== 1'b1 && k < LIMITE) begin @(negedge clk); k = k + 1; end
        verifica(k == P,          "T5: aumentar no meio nao religa o pwm antes do fim do periodo");
        mede(alto, periodo);
        verifica(alto == 80*DIV,  "T5: novo duty (80) vale a partir do periodo seguinte");

        // 6) Reduzir no meio do periodo (saida ainda em 1): pulso inteiro
        espera_subida;                  // ja com duty 80
        k = 0;
        repeat (40*DIV) begin @(negedge clk); k = k + 1; end   // passo ~40: pwm em 1
        duty = 7'd20;
        while (pwm === 1'b1 && k < LIMITE) begin @(negedge clk); k = k + 1; end
        verifica(k == 80*DIV,     "T6: reduzir no meio nao corta o pulso atual (80)");
        espera_subida;
        mede(alto, periodo);
        verifica(alto == 20*DIV,  "T6: novo duty (20) vale a partir do periodo seguinte");

        // 7) Habilitacao
        duty = 7'd50;
        repeat (2*P) @(negedge clk);
        espera_subida;
        repeat (10) @(negedge clk);     // pwm em 1
        en = 1'b0;
        @(negedge clk);
        verifica(pwm === 1'b0,    "T7: en = 0 zera o pwm no ciclo seguinte");
        observa(2*P);
        verifica(!teve_1,         "T7: pwm fica em 0 enquanto en = 0");
        en = 1'b1;
        k = 0;
        while (pwm !== 1'b1 && k < LIMITE) begin @(negedge clk); k = k + 1; end
        verifica(k <= 2,          "T7: en = 1 comeca um periodo novo na hora");
        mede(alto, periodo);
        verifica(alto == 50*DIV && periodo == P, "T7: primeiro periodo apos en = 1 e inteiro (duty 50)");

        // 8) Parametros reais: 1 kHz @ 50 MHz
        begin : real_freq
            integer t, h, per;
            reg     ant;
            // espera uma subida do pwm_real
            ant = pwm_real; t = 0;
            while (!(ant === 1'b0 && pwm_real === 1'b1) && t < 200000) begin
                ant = pwm_real; @(negedge clk); t = t + 1;
            end
            h = 0; per = 0;
            while (pwm_real === 1'b1 && per < 200000) begin h = h + 1; per = per + 1; @(negedge clk); end
            while (pwm_real === 1'b0 && per < 200000) begin per = per + 1; @(negedge clk); end
            $display("     T8: parametros reais -> periodo = %0d ciclos (%0d us), em 1 = %0d ciclos",
                     per, per*T_CLK/1000, h);
            verifica(per == 50000,    "T8: periodo de 50.000 ciclos = 1 kHz @ 50 MHz");
            verifica(h == 25000,      "T8: duty 50 -> 25.000 ciclos em 1");
        end

        // Resultado
        $display("==================================================");
        if (erros == 0)
            $display("PASS: todos os testes do pwm_gen passaram");
        else
            $display("FAIL: %0d erro(s) encontrado(s)", erros);
        $display("==================================================");
        $finish;
    end

    // Protecao contra simulacao travada
    initial begin
        #(T_CLK * 1000000);
        $display("FAIL: timeout da simulacao");
        $finish;
    end

endmodule
