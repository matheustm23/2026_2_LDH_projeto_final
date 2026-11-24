`timescale 1ns/1ps
// ============================================================
// Arquivo  : tb_fsm_sentido.v
// Item     : 1 - Inversao do sentido de rotacao
// Autor    : Matheus
// Descricao: Testbench autoverificavel do fsm_sentido. Usa uma
//            pausa curta (PAUSA_CICLOS = 20) para simular rapido.
//            Testes:
//              1) estado apos o reset
//              2) troca 0 -> 1 com pausa de exatamente 20 ciclos
//              3) troca 1 -> 0
//              4) chave volta durante a pausa (sentido nao muda)
//              5) reset no meio da pausa
//            Verifica tambem, a cada ciclo, que in1 = dir,
//            in2 = ~dir e pwm_en = ~troca.
// ============================================================
module tb_fsm_sentido;

    localparam PAUSA     = 20;          // pausa curta para simulacao
    localparam T_CLK     = 20;          // periodo de 20 ns = 50 MHz
    localparam MAX_LAT   = 4;           // ciclos max. entre mudar a chave e iniciar a pausa

    // --------------------------------------------------------
    // Sinais do DUT
    // --------------------------------------------------------
    reg  clk    = 1'b0;
    reg  rst    = 1'b1;
    reg  sw_dir = 1'b0;
    wire dir, pwm_en, troca, in1, in2;

    integer erros = 0;
    integer dur;                        // duracao medida da pausa
    integer i;
    reg     dir_antes;

    fsm_sentido #(.PAUSA_CICLOS(PAUSA)) dut (
        .clk    (clk),
        .rst    (rst),
        .sw_dir (sw_dir),
        .dir    (dir),
        .pwm_en (pwm_en),
        .troca  (troca),
        .in1    (in1),
        .in2    (in2)
    );

    // Clock de 50 MHz
    always #(T_CLK/2) clk = ~clk;

    // --------------------------------------------------------
    // Verificacao continua (amostra na borda de descida)
    // --------------------------------------------------------
    always @(negedge clk) begin
        if (!rst) begin
            if (in1 !== dir || in2 !== ~dir) begin
                $display("FAIL [%0d ns]: in1/in2 nao correspondem a dir", $time);
                erros = erros + 1;
            end
            if (pwm_en !== ~troca) begin
                $display("FAIL [%0d ns]: pwm_en deveria ser o inverso de troca", $time);
                erros = erros + 1;
            end
        end
    end

    // --------------------------------------------------------
    // Tarefas auxiliares
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

    // Espera a pausa comecar (ate MAX_LAT ciclos) e mede quantos
    // ciclos ela dura. Confere que dir nao muda durante a pausa.
    task mede_pausa;
        output integer duracao;
        integer lat;
        begin
            duracao = 0;
            lat     = 0;
            while (troca !== 1'b1 && lat <= MAX_LAT) begin
                @(negedge clk);
                lat = lat + 1;
            end
            if (troca !== 1'b1) begin
                $display("FAIL [%0d ns]: a pausa nao comecou em %0d ciclos", $time, MAX_LAT);
                erros = erros + 1;
            end else begin
                dir_antes = dir;
                while (troca === 1'b1) begin
                    if (dir !== dir_antes) begin
                        $display("FAIL [%0d ns]: dir mudou durante a pausa", $time);
                        erros = erros + 1;
                    end
                    duracao = duracao + 1;
                    @(negedge clk);
                end
            end
        end
    endtask

    // Confere que nenhuma pausa acontece durante n ciclos
    task sem_pausa;
        input integer n;
        integer k;
        reg     teve_pausa;
        begin
            teve_pausa = 1'b0;
            for (k = 0; k < n; k = k + 1) begin
                @(negedge clk);
                if (troca === 1'b1) teve_pausa = 1'b1;
            end
            verifica(!teve_pausa, "nenhuma pausa extra");
        end
    endtask

    // --------------------------------------------------------
    // Sequencia de testes
    // --------------------------------------------------------
    initial begin
        $display("=== tb_fsm_sentido (PAUSA_CICLOS = %0d) ===", PAUSA);

        // 1) Reset
        repeat (5) @(negedge clk);
        rst = 1'b0;
        repeat (5) @(negedge clk);
        verifica(dir === 1'b0,    "T1: apos reset dir = 0 (anti-horario)");
        verifica(pwm_en === 1'b1, "T1: apos reset pwm_en = 1");
        verifica(troca === 1'b0,  "T1: apos reset troca = 0");
        verifica(in1 === 1'b0 && in2 === 1'b1, "T1: in1 = 0, in2 = 1");

        // 2) Troca 0 -> 1
        sw_dir = 1'b1;
        mede_pausa(dur);
        verifica(dur == PAUSA,    "T2: pausa de exatamente PAUSA_CICLOS");
        verifica(dir === 1'b1,    "T2: dir = 1 (horario) apos a pausa");
        verifica(pwm_en === 1'b1, "T2: pwm_en religado apos a pausa");
        verifica(in1 === 1'b1 && in2 === 1'b0, "T2: in1 = 1, in2 = 0");
        sem_pausa(2*PAUSA);

        // 3) Troca 1 -> 0
        sw_dir = 1'b0;
        mede_pausa(dur);
        verifica(dur == PAUSA,    "T3: pausa de exatamente PAUSA_CICLOS");
        verifica(dir === 1'b0,    "T3: dir = 0 (anti-horario) apos a pausa");
        sem_pausa(2*PAUSA);

        // 4) Chave volta para a posicao original no meio da pausa
        sw_dir = 1'b1;
        i = 0;
        while (troca !== 1'b1 && i <= MAX_LAT) begin
            @(negedge clk);
            i = i + 1;
        end
        verifica(troca === 1'b1,  "T4: pausa iniciada");
        repeat (PAUSA/2) @(negedge clk);
        sw_dir = 1'b0;                  // volta antes do fim da pausa
        i = 0;
        while (troca === 1'b1 && i <= PAUSA) begin
            @(negedge clk);
            i = i + 1;
        end
        verifica(troca === 1'b0,  "T4: pausa terminou");
        verifica(dir === 1'b0,    "T4: dir continua 0 (chave voltou)");
        verifica(pwm_en === 1'b1, "T4: pwm_en religado");
        sem_pausa(2*PAUSA);

        // 5) Reset no meio da pausa
        sw_dir = 1'b1;
        i = 0;
        while (troca !== 1'b1 && i <= MAX_LAT) begin
            @(negedge clk);
            i = i + 1;
        end
        repeat (5) @(negedge clk);
        rst = 1'b1;
        repeat (2) @(negedge clk);
        verifica(troca === 1'b0 && dir === 1'b0 && pwm_en === 1'b1,
                 "T5: reset durante a pausa volta para RODANDO, dir = 0");
        rst = 1'b0;
        // chave continua em 1 e dir = 0: nova pausa e troca para 1
        mede_pausa(dur);
        verifica(dur == PAUSA,    "T5: nova pausa completa apos o reset");
        verifica(dir === 1'b1,    "T5: dir = 1 apos a pausa");

        // Resultado
        $display("==================================================");
        if (erros == 0)
            $display("PASS: todos os testes do fsm_sentido passaram");
        else
            $display("FAIL: %0d erro(s) encontrado(s)", erros);
        $display("==================================================");
        $finish;
    end

    // Protecao contra simulacao travada
    initial begin
        #(T_CLK * 5000);
        $display("FAIL: timeout da simulacao");
        $finish;
    end

endmodule
