/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 3                                               */
/* Hyperbolic Tangent (Tanh) circuit                   */
/*******************************************************/

module tanh (
    input  clk,         // Input clock signal
    input  rst,         // Active-high reset signal
    // Input interface
    input  [13:0] i_x,  // Input value x
    input  i_valid,     // Input value x is valid
    output o_ready,     // Circuit is ready to accept an input
    // Output interface
    output [13:0] o_fx, // Output result f(x)
    output o_valid,     // Output result f(x) is valid
    input  i_ready      // Downstream circuit is ready to accept an input
);

    // Local parameters to define the Taylor coefficients (Q2.12 signed)
    localparam signed [13:0] A0 = 14'b11101010101011; // a0 = -0.33349609375
    localparam signed [13:0] A1 = 14'b00001000100010; // a1 =  0.13330078125
    localparam signed [13:0] A2 = 14'b11111100100011; // a2 = -0.05419921875
    localparam signed [13:0] A3 = 14'b00000001011001; // a3 =  0.021484375
    localparam signed [13:0] A4 = 14'b11111111011100; // a4 = -0.0087890625

/******* Your code starts here *******/
    localparam int FRAC = 12;
    wire en = (!rst) && i_ready;
    assign o_ready = en;

    function automatic logic signed [13:0] q_add_trunc(
        input logic signed [13:0] a,
        input logic signed [13:0] b
    );
        logic signed [14:0] sum;
        begin
            sum = a + b;
            q_add_trunc = sum[13:0];
        end
    endfunction

    module delay_ce #(
        parameter int W = 1,
        parameter int N = 1
    )(
        input logic clk,
        input logic rst,
        input logic en,
        input logic [W-1:0] d,
        output logic [W-1:0] q
    );
        logic [W-1:0] pipe [0:N];
        integer i;
        always_ff @(posedge clk) begin
            if (rst) begin
                for (i = 0; i <= N; i++) pipe[i] <= '0;
            end else if (en) begin
                pipe[0] <= d;
                for (i = 1; i <= N; i++) pipe[i] <= pipe[i-1];
            end
        end
        assign q = pipe[N];
    endmodule

    module dsp_mul_q212 #(
        parameter int FRAC = 12,
        parameter int LAT  = 4
    )(
        input logic clk,
        input logic rst,
        input logic en,
        input logic signed [13:0] a_q,
        input logic signed [13:0] b_q,
        output logic signed [13:0] p_q
    );
        logic [29:0] A;
        logic [17:0] B;
        logic [47:0] P;

        always_comb begin
            A = {{(30-14){a_q[13]}}, a_q};
            B = {{(18-14){b_q[13]}}, b_q};
        end

                DSP48E2 #(
            .USE_MULT("MULTIPLY"), .USE_SIMD("ONE48"), .AREG(2),
            .BREG(2), .MREG(1), .PREG(1),
            .ACASCREG(2), .BCASCREG(2), .CREG(0),
            .DREG(0), .ADREG(0), .INMODEREG(1),
            .OPMODEREG(1), .ALUMODEREG(1), .CARRYINREG(0),
            .CARRYINSELREG(0)
        ) u_dsp (
            .CLK(clk), .A(A), .B(B), .C(48'b0), .D(27'b0),
            .ACIN(30'b0), .BCIN(18'b0), .PCIN(48'b0),
            .ALUMODE(4'b0000), .CARRYINSEL(3'b000), .INMODE(5'b00000),
            .OPMODE(9'b000000101), .CARRYIN(1'b0),
            .CEA1(en), .CEA2(en), .CEB1(en), .CEB2(en),
            .CEC(en), .CED(en), .CEAD(en),
            .CEINMODE(en), .CECTRL(en), .CEALUMODE(en), .CECARRYIN(en),
            .CEM(en), .CEP(en), .RSTA(rst), .RSTB(rst), .RSTC(rst),
            .RSTD(rst), .RSTCTRL(rst), .RSTINMODE(rst), .RSTALUMODE(rst),
            .RSTALLCARRYIN(rst), .RSTM(rst), .RSTP(rst),
            .P(P), .PCOUT(), .ACOUT(), .BCOUT(),
            .CARRYCASCOUT(), .CARRYOUT(), .MULTSIGNOUT(), .OVERFLOW(),
            .UNDERFLOW(), .PATTERNDETECT(), .PATTERNBDETECT(), .XOROUT()
        );

        always_ff @(posedge clk) begin
            if (rst) p_q <= '0;
            else if (en) p_q <= $signed(P[FRAC+13:FRAC]);
        end
    endmodule


    module mul_stage #(
        parameter int LAT  = 4
    )(
        input logic clk,
        input logic rst,
        input logic en,
        input logic v_in,
        input logic signed [13:0] x_in,
        input logic signed [13:0] x2_in,
        input logic signed [13:0] a_in,
        input logic signed [13:0] b_in,
        output logic v_out,
        output logic signed [13:0] x_out,
        output logic signed [13:0] x2_out,
        output logic signed [13:0] p_out
    );

        dsp_mul_q212 #(.FRAC(FRAC), .LAT(LAT)) u_mul (
            .clk(clk), .rst(rst), .en(en),
            .a_q(a_in), .b_q(b_in),
            .p_q(p_out)
        );

        delay_ce #(.W(1), .N(LAT)) u_dv (.clk(clk), .rst(rst), .en(en), .d(v_in), .q(v_out));
        delay_ce #(.W(14), .N(LAT)) u_dx (.clk(clk), .rst(rst), .en(en), .d(x_in), .q(x_out));
        delay_ce #(.W(14), .N(LAT)) u_dx2 (.clk(clk), .rst(rst), .en(en), .d(x2_in), .q(x2_out));

    endmodule

    module add_stage #(
        parameter logic signed [13:0] K = 14'sd0
    )(
        input logic clk,
        input logic rst,
        input logic en,
        input logic v_in,
        input logic signed [13:0] x_in,
        input logic signed [13:0] x2_in,
        input logic signed [13:0] t_in,
        output logic v_out,
        output logic signed [13:0] x_out,
        output logic signed [13:0] x2_out,
        output logic signed [13:0] t_out
    );
        always_ff @(posedge clk) begin
            if (rst) begin
                v_out <= 1'b0;
                x_out <= '0;
                x2_out <= '0;
                t_out <= '0;
            end else if (en) begin
                v_out <= v_in;
                x_out <= x_in;
                x2_out <= x2_in;
                t_out <= q_add_trunc(t_in, K);
            end
        end
    endmodule

    localparam int LAT = 4;

    // Stage S0: register input
    logic               v0;
    logic signed [13:0] x0;
    always_ff @(posedge clk) begin
        if (rst) begin
            v0 <= 1'b0;
            x0 <= '0;
        end else if (en) begin
            v0 <= i_valid;
            x0 <= $signed(i_x);
        end
    end
    logic signed [13:0] x2_0;
    assign x2_0 = 14'sd0;

    // S1: x2 = x*x  (DSP)
    logic v1;
    logic signed [13:0] x1, x2_1;
    logic signed [13:0] x2_calc;
    mul_stage #(.LAT(LAT)) S1_x2 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v0), .x_in(x0), .x2_in(x2_0),
        .a_in(x0), .b_in(x0),
        .v_out(v1), .x_out(x1), .x2_out(),
        .p_out(x2_calc)
    );
    assign x2_1 = x2_calc;

    // S2: t = A4 * x2 (DSP)
    logic v2;
    logic signed [13:0] x2, x2_2;
    logic signed [13:0] t2_mul;
    mul_stage #(.LAT(LAT)) S2_a4x2 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v1), .x_in(x1), .x2_in(x2_1),
        .a_in(A4), .b_in(x2_1),
        .v_out(v2), .x_out(x2), .x2_out(x2_2),
        .p_out(t2_mul)
    );

    // S3: t = t + A3 (REG ADD)
    logic v3;
    logic signed [13:0] x3, x2_3, t3;
    add_stage #(.K(A3)) S3_addA3 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v2), .x_in(x2), .x2_in(x2_2), .t_in(t2_mul),
        .v_out(v3), .x_out(x3), .x2_out(x2_3), .t_out(t3)
    );

    // S4: t = t * x2 (DSP)
    logic v4;
    logic signed [13:0] x4, x2_4, t4_mul;
    mul_stage #(.LAT(LAT)) S4_t3x2 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v3), .x_in(x3), .x2_in(x2_3),
        .a_in(t3), .b_in(x2_3),
        .v_out(v4), .x_out(x4), .x2_out(x2_4),
        .p_out(t4_mul)
    );

    // S5: t = t + A2
    logic v5;
    logic signed [13:0] x5, x2_5, t5;
    add_stage #(.K(A2)) S5_addA2 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v4), .x_in(x4), .x2_in(x2_4), .t_in(t4_mul),
        .v_out(v5), .x_out(x5), .x2_out(x2_5), .t_out(t5)
    );

    // S6: t = t * x2 (DSP)
    logic v6;
    logic signed [13:0] x6, x2_6, t6_mul;
    mul_stage #(.LAT(LAT)) S6_t5x2 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v5), .x_in(x5), .x2_in(x2_5),
        .a_in(t5), .b_in(x2_5),
        .v_out(v6), .x_out(x6), .x2_out(x2_6),
        .p_out(t6_mul)
    );

    // S7: t = t + A1
    logic v7;
    logic signed [13:0] x7, x2_7, t7;
    add_stage #(.K(A1)) S7_addA1 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v6), .x_in(x6), .x2_in(x2_6), .t_in(t6_mul),
        .v_out(v7), .x_out(x7), .x2_out(x2_7), .t_out(t7)
    );

    // S8: t = t * x2 (DSP)
    logic v8;
    logic signed [13:0] x8, x2_8, t8_mul;
    mul_stage #(.LAT(LAT)) S8_t7x2 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v7), .x_in(x7), .x2_in(x2_7),
        .a_in(t7), .b_in(x2_7),
        .v_out(v8), .x_out(x8), .x2_out(x2_8),
        .p_out(t8_mul)
    );

    // S9: t = t + A0
    logic v9;
    logic signed [13:0] x9, x2_9, t9;
    add_stage #(.K(A0)) S9_addA0 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v8), .x_in(x8), .x2_in(x2_8), .t_in(t8_mul),
        .v_out(v9), .x_out(x9), .x2_out(x2_9), .t_out(t9)
    );

    // S10: t = t * x2 (DSP)  => ... * x^2
    logic v10;
    logic signed [13:0] x10, x2_10, t10_mul;
    mul_stage #(.LAT(LAT)) S10_t9x2 (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v9), .x_in(x9), .x2_in(x2_9),
        .a_in(t9), .b_in(x2_9),
        .v_out(v10), .x_out(x10), .x2_out(x2_10),
        .p_out(t10_mul)
    );

    // S11: t = t * x (DSP)   => ... * x^3
    logic v11;
    logic signed [13:0] x11, x2_11, t11_mul;
    mul_stage #(.LAT(LAT)) S11_t10x (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v10), .x_in(x10), .x2_in(x2_10),
        .a_in(t10_mul), .b_in(x10),
        .v_out(v11), .x_out(x11), .x2_out(x2_11),
        .p_out(t11_mul)
    );

    // S12: fx = t + x (REG ADD)
    logic v12;
    logic signed [13:0] x12, x2_12, fx12;
    add_stage #(.K(14'sd0)) S12_addX (
        .clk(clk), .rst(rst), .en(en),
        .v_in(v11), .x_in(x11), .x2_in(x2_11), .t_in(t11_mul),
        .v_out(v12), .x_out(x12), .x2_out(x2_12), .t_out(fx12)
    );

    // final output = fx12 + x12
    logic signed [13:0] fx_reg;
    always_ff @(posedge clk) begin
        if (rst) begin
            fx_reg <= '0;
        end else if (en) begin
            fx_reg <= q_add_trunc(fx12, x12);
        end
    end

    logic v_out;
    always_ff @(posedge clk) begin
        if (rst) v_out <= 1'b0;
        else if (en) v_out <= v12;
    end

    assign o_fx    = fx_reg;
    assign o_valid = v_out;

/******* Your code ends here ********/

endmodule