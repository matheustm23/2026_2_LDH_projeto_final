`timescale 1ns/1ps
// ============================================================
// Arquivo  : tb_setpoint_ctrl.v
// Item     : 2 - Ajuste do setpoint do PWM
// Autor    : Luis
// Descricao: Testbench autoverificavel do setpoint_ctrl. Usa um
//            debounce curto (DEBOUNCE_CICLOS = 10) para simular
//            rapido. Testes:
//              1) estado apos o reset (duty = 0)
//              2) um toque em KEY1 com repique -> +5, 1 pulso
//              3) botao segurado conta um unico passo
//              4) repique na soltura nao conta como toque
//              5) glitch menor que o debounce e ignorado
//              6) satura em 100
//              7) KEY0 reduz e satura em 0
//              8) dois botoes no mesmo ciclo: duty nao muda
//              9) reset no meio da operacao
//            Verifica tambem, a cada ciclo, que ajuste dura 1
//            ciclo e que duty e sempre multiplo de 5 entre 0 e 100.
// ============================================================
module tb_setpoint_ctrl;

    localparam DEB   = 10;              // debounce curto para simulacao
    localparam T_CLK = 20;              // periodo de 20 ns = 50 MHz

    // --------------------------------------------------------
    // Sinais do DUT
    // --------------------------------------------------------
    reg        clk        = 1'b0;
    reg        rst        = 1'b1;
    reg        key_up_n   = 1'b1;       // botoes soltos (ativos em 0)
    reg        key_down_n = 1'b1;
    wire [6:0] duty;
    wire       ajuste;

    integer erros    = 0;
    integer pulsos   = 0;               // pulsos de ajuste contados
    integer i;
    reg     ajuste_ant = 1'b0;

    setpoint_ctrl #(.DEBOUNCE_CICLOS(DEB)) dut (
        .clk        (clk),
        .rst        (rst),
        .key_up_n   (key_up_n),
        .key_down_n (key_down_n),
        .duty       (duty),
        .ajuste     (ajuste)
    );

    // Clock de 50 MHz
    always #(T_CLK/2) clk = ~clk;

    // --------------------------------------------------------
    // Verificacao continua (amostra na borda de descida)
    // --------------------------------------------------------
    always @(negedge clk) begin
        if (!rst) begin
            if (ajuste === 1'b1) pulsos = pulsos + 1;
            if (ajuste === 1'b1 && ajuste_ant === 1'b1) begin
                $display("FAIL [%0d ns]: ajuste ficou em 1 por mais de um ciclo", $time);
                erros = erros + 1;
            end
            if (duty > 7'd100 || (duty % 5) != 0) begin
                $display("FAIL [%0d ns]: duty invalido (%0d)", $time, duty);
                erros = erros + 1;
            end
        end
        ajuste_ant = ajuste;
    end

    // --------------------------------------------------------
    // Tarefas auxiliares
    // --------------------------------------------------------
    task verifica;
        input        cond;
        input [8*64-1:0] msg;
        begin
            if (cond !== 1'b1) begin
                $display("FAIL [%0d ns]: %0s (duty = %0d)", $time, msg, duty);
                erros = erros + 1;
            end else begin
                $display("ok   [%0d ns]: %0s (duty = %0d)", $time, msg, duty);
            end
        end
    endtask

    // Muda o nivel de um botao com repique: alterna o nivel varias
    // vezes com intervalos menores que o debounce e termina no
    // nivel final. qual = 1 -> KEY1, qual = 0 -> KEY0
    task muda_com_repique;
        input qual;
        input nivel;
        integer r;
        begin
            for (r = 0; r < 4; r = r + 1) begin
                if (qual) key_up_n = nivel; else key_down_n = nivel;
                repeat (2) @(negedge clk);
                if (qual) key_up_n = ~nivel; else key_down_n = ~nivel;
                repeat (2) @(negedge clk);
            end
            if (qual) key_up_n = nivel; else key_down_n = nivel;
        end
    endtask

    // Um toque completo: aperta com repique, segura, solta com
    // repique e espera estabilizar
    task toque;
        input qual;
        begin
            muda_com_repique(qual, 1'b0);
            repeat (3*DEB) @(negedge clk);
            muda_com_repique(qual, 1'b1);
            repeat (3*DEB) @(negedge clk);
        end
    endtask

    // --------------------------------------------------------
    // Sequencia de testes
    // --------------------------------------------------------
    initial begin
        $display("=== tb_setpoint_ctrl (DEBOUNCE_CICLOS = %0d) ===", DEB);

        // 1) Reset
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (3*DEB) @(negedge clk);
        verifica(duty == 7'd0,    "T1: apos reset duty = 0");
        verifica(pulsos == 0,     "T1: nenhum pulso de ajuste");

        // 2) Um toque em KEY1 com repique
        pulsos = 0;
        toque(1'b1);
        verifica(duty == 7'd5,    "T2: um toque em KEY1 -> duty = 5");
        verifica(pulsos == 1,     "T2: exatamente 1 pulso de ajuste");

        // 3) Botao segurado por muito tempo conta um passo so
        pulsos = 0;
        muda_com_repique(1'b1, 1'b0);
        repeat (20*DEB) @(negedge clk);
        verifica(duty == 7'd10,   "T3: segurando KEY1 -> so +5");
        verifica(pulsos == 1,     "T3: exatamente 1 pulso com o botao segurado");

        // 4) Repique na soltura nao conta
        pulsos = 0;
        muda_com_repique(1'b1, 1'b1);
        repeat (3*DEB) @(negedge clk);
        verifica(duty == 7'd10,   "T4: soltar KEY1 nao muda o duty");
        verifica(pulsos == 0,     "T4: nenhum pulso ao soltar");

        // 5) Glitch menor que o debounce
        pulsos = 0;
        key_up_n = 1'b0;
        repeat (DEB/2) @(negedge clk);
        key_up_n = 1'b1;
        repeat (3*DEB) @(negedge clk);
        verifica(duty == 7'd10,   "T5: glitch curto em KEY1 e ignorado");
        verifica(pulsos == 0,     "T5: nenhum pulso no glitch");

        // 6) Satura em 100 (sobe 20 vezes a partir de 10)
        pulsos = 0;
        for (i = 0; i < 20; i = i + 1) toque(1'b1);
        verifica(duty == 7'd100,  "T6: duty satura em 100");
        verifica(pulsos == 20,    "T6: 20 pulsos de ajuste (inclusive saturado)");

        // 7) KEY0 reduz e satura em 0
        toque(1'b0);
        verifica(duty == 7'd95,   "T7: um toque em KEY0 -> duty = 95");
        for (i = 0; i < 25; i = i + 1) toque(1'b0);
        verifica(duty == 7'd0,    "T7: duty satura em 0");

        // 8) Dois botoes no mesmo ciclo
        toque(1'b1);                    // duty = 5
        pulsos = 0;
        key_up_n   = 1'b0;
        key_down_n = 1'b0;
        repeat (3*DEB) @(negedge clk);
        key_up_n   = 1'b1;
        key_down_n = 1'b1;
        repeat (3*DEB) @(negedge clk);
        verifica(duty == 7'd5,    "T8: dois botoes juntos -> duty nao muda");
        verifica(pulsos == 1,     "T8: um pulso de ajuste");

        // 9) Reset no meio da operacao
        toque(1'b1);
        toque(1'b1);                    // duty = 15
        rst = 1'b1;
        repeat (2) @(negedge clk);
        verifica(duty == 7'd0,    "T9: reset zera o duty");
        rst = 1'b0;
        repeat (3*DEB) @(negedge clk);
        toque(1'b1);
        verifica(duty == 7'd5,    "T9: volta a funcionar apos o reset");

        // Resultado
        $display("==================================================");
        if (erros == 0)
            $display("PASS: todos os testes do setpoint_ctrl passaram");
        else
            $display("FAIL: %0d erro(s) encontrado(s)", erros);
        $display("==================================================");
        $finish;
    end

    // Protecao contra simulacao travada
    initial begin
        #(T_CLK * 200000);
        $display("FAIL: timeout da simulacao");
        $finish;
    end

endmodule
