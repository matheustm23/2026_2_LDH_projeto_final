`timescale 1ns/1ps
// ============================================================
// Arquivo  : encoder_x4.v
// Item     : 4 - Leitura do encoder
// Autor    : Luis
// Descricao: Le os canais A e B do encoder Hall do motor e conta
//            todas as bordas dos dois canais (decodificacao x4).
//            Etapas:
//              1) sincronizador de 2 flip-flops nos dois canais
//              2) filtro de ruido: cada canal so muda depois de
//                 ficar FILTRO_CICLOS ciclos estavel (rejeita
//                 pulsos curtos induzidos pelo PWM do motor)
//              3) decodificacao da sequencia de quadratura
//            Sequencia {A,B} no sentido horario (A adiantado de B):
//              00 -> 10 -> 11 -> 01 -> 00
//            No sentido anti-horario a sequencia e a inversa.
//            Mudanca dos dois canais no mesmo ciclo e invalida e
//            e ignorada. No reset os canais filtrados recebem o
//            nivel atual das entradas, entao nao aparece passo
//            falso ao sair do reset.
//            Encoder do motor: 11 pulsos por volta do eixo do motor
//            por canal -> 44 contagens por volta do motor em x4.
// Portas   : clk     - clock de 50 MHz
//            rst     - reset sincrono, ativo em 1 (zera pos)
//            enc_a   - canal A cru (GPIO[3])
//            enc_b   - canal B cru (GPIO[4])
//            step    - pulso de 1 ciclo por transicao valida (x4)
//            dir_enc - sentido medido (1 = horario)
//            pos     - contagem acumulada (+1 horario, -1 anti-horario)
// ============================================================
module encoder_x4 #(
    parameter FILTRO_CICLOS = 50,       // 1 us @ 50 MHz
    parameter INVERTE       = 1'b0      // 1 inverte o sentido medido (em vez de trocar os fios A/B)
)(
    input  wire               clk,
    input  wire               rst,
    input  wire               enc_a,    // canal A cru (GPIO[3])
    input  wire               enc_b,    // canal B cru (GPIO[4])
    output wire               step,     // pulso de 1 ciclo por transicao valida (x4)
    output wire               dir_enc,  // sentido medido (1 = horario)
    output reg  signed [31:0] pos       // contagem acumulada (calibracao/debug)
);

    // --------------------------------------------------------
    // Constantes
    // --------------------------------------------------------
    localparam F_W = $clog2(FILTRO_CICLOS + 1);
    localparam [F_W-1:0] F_ULT = FILTRO_CICLOS - 1;   // ultimo ciclo do filtro

    // --------------------------------------------------------
    // 1) Sincronizacao dos canais (bit 1 = A, bit 0 = B)
    // --------------------------------------------------------
    wire [1:0] ab_sync;

    sync_2ff #(.WIDTH(2)) u_sync_enc (
        .clk (clk),
        .d   ({enc_a, enc_b}),
        .q   (ab_sync)
    );

    wire a_sync = ab_sync[1];
    wire b_sync = ab_sync[0];

    // --------------------------------------------------------
    // 2) Filtro de ruido de cada canal
    // --------------------------------------------------------
    reg           a_f;                  // canal A filtrado
    reg           b_f;                  // canal B filtrado
    reg [F_W-1:0] cnt_a;                // tempo que A esta diferente de a_f
    reg [F_W-1:0] cnt_b;                // tempo que B esta diferente de b_f

    always @(posedge clk) begin
        if (rst) begin
            a_f   <= a_sync;            // carrega o nivel atual (sem passo falso)
            cnt_a <= {F_W{1'b0}};
        end else if (a_sync == a_f) begin
            cnt_a <= {F_W{1'b0}};
        end else if (cnt_a == F_ULT) begin
            a_f   <= a_sync;            // ficou estavel o tempo todo: aceita
            cnt_a <= {F_W{1'b0}};
        end else begin
            cnt_a <= cnt_a + 1'b1;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            b_f   <= b_sync;
            cnt_b <= {F_W{1'b0}};
        end else if (b_sync == b_f) begin
            cnt_b <= {F_W{1'b0}};
        end else if (cnt_b == F_ULT) begin
            b_f   <= b_sync;
            cnt_b <= {F_W{1'b0}};
        end else begin
            cnt_b <= cnt_b + 1'b1;
        end
    end

    // --------------------------------------------------------
    // 3) Decodificacao x4
    // --------------------------------------------------------
    reg  [1:0] ab_ant;                  // {A,B} filtrado no ciclo anterior
    wire [3:0] trans;                   // {A_ant, B_ant, A, B}
    reg        frente;                  // transicao no sentido A adiantado de B
    reg        tras;                    // transicao no sentido B adiantado de A

    always @(posedge clk) begin
        if (rst)
            ab_ant <= ab_sync;          // mesmo valor que a_f/b_f recebem no reset
        else
            ab_ant <= {a_f, b_f};
    end

    assign trans = {ab_ant, a_f, b_f};

    always @(*) begin
        frente = 1'b0;
        tras   = 1'b0;
        case (trans)
            4'b0010, 4'b1011, 4'b1101, 4'b0100: frente = 1'b1;   // 00->10->11->01->00
            4'b0001, 4'b0111, 4'b1110, 4'b1000: tras   = 1'b1;   // 00->01->11->10->00
            default: begin                                       // sem mudanca ou invalida
                frente = 1'b0;
                tras   = 1'b0;
            end
        endcase
    end

    wire sobe;                          // passo no sentido horario
    wire desce;                         // passo no sentido anti-horario

    assign sobe  = INVERTE ? tras   : frente;
    assign desce = INVERTE ? frente : tras;
    assign step  = sobe | desce;

    // --------------------------------------------------------
    // Posicao acumulada e sentido medido
    // --------------------------------------------------------
    reg dir_r;

    always @(posedge clk) begin
        if (rst) begin
            pos   <= 32'sd0;
            dir_r <= 1'b0;
        end else if (sobe) begin
            pos   <= pos + 32'sd1;
            dir_r <= 1'b1;
        end else if (desce) begin
            pos   <= pos - 32'sd1;
            dir_r <= 1'b0;
        end
    end

    assign dir_enc = dir_r;

endmodule
