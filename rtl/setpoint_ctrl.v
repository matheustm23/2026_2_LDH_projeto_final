`timescale 1ns/1ps
// Ajuste do setpoint em passos de 5%, com sincronizacao,
// debounce e deteccao de borda de pressionamento.
module setpoint_ctrl #(
    parameter DEBOUNCE_CICLOS = 500_000
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       key_up_n,       // KEY1: ativo em 0
    input  wire       key_down_n,     // KEY0: ativo em 0
    output reg  [6:0] duty,           // 0 a 100%
    output reg        ajuste          // pulso de um ciclo ao ajustar
);
    wire key_up_sync;
    wire key_down_sync;
    wire key_up_clean;
    wire key_down_clean;

    reg key_up_prev;
    reg key_down_prev;

    wire up_press;
    wire down_press;

    sync_2ff #(.WIDTH(1)) u_sync_up (
        .clk(clk),
        .d(key_up_n),
        .q(key_up_sync)
    );

    sync_2ff #(.WIDTH(1)) u_sync_down (
        .clk(clk),
        .d(key_down_n),
        .q(key_down_sync)
    );

    debounce #(.DEBOUNCE_CICLOS(DEBOUNCE_CICLOS)) u_debounce_up (
        .clk(clk),
        .rst(rst),
        .noisy(key_up_sync),
        .clean(key_up_clean)
    );

    debounce #(.DEBOUNCE_CICLOS(DEBOUNCE_CICLOS)) u_debounce_down (
        .clk(clk),
        .rst(rst),
        .noisy(key_down_sync),
        .clean(key_down_clean)
    );

    // KEY e ativo em 0: borda de descida representa pressionamento.
    assign up_press   = key_up_prev   && !key_up_clean;
    assign down_press = key_down_prev && !key_down_clean;

    always @(posedge clk) begin
        if (rst) begin
            key_up_prev   <= 1'b1;
            key_down_prev <= 1'b1;
            duty          <= 7'd0;
            ajuste        <= 1'b0;
        end else begin
            key_up_prev   <= key_up_clean;
            key_down_prev <= key_down_clean;
            ajuste        <= 1'b0;

            // Se os dois botoes forem pressionados juntos, nenhum ajuste
            // e realizado para evitar uma decisao ambigua.
            if (up_press && !down_press) begin
                if (duty <= 7'd95)
                    duty <= duty + 7'd5;
                else
                    duty <= 7'd100;
                ajuste <= 1'b1;
            end else if (down_press && !up_press) begin
                if (duty >= 7'd5)
                    duty <= duty - 7'd5;
                else
                    duty <= 7'd0;
                ajuste <= 1'b1;
            end
        end
    end
endmodule
