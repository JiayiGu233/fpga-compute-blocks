/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 4                                               */
/* 8-Lane Dot Product Module                           */
/*******************************************************/

module dot8 # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 24
)(
    input  logic clk,
    input  logic rst,
    input  logic signed [8*IWIDTH-1:0] vec0,
    input  logic signed [8*IWIDTH-1:0] vec1,
    input  logic ivalid,
    output logic signed [OWIDTH-1:0] result,
    output logic ovalid
);

/******* Your code starts here *******/

localparam int NLANES = 8;
localparam int PROD_W = 2 * IWIDTH;   // 16 when IWIDTH=8
localparam int SUM1_W = PROD_W + 1;
localparam int SUM2_W = PROD_W + 2;
localparam int SUM3_W = PROD_W + 3;

logic [4:0] valid_pipe;
logic signed [IWIDTH-1:0] a_lane [0:NLANES-1];
logic signed [IWIDTH-1:0] b_lane [0:NLANES-1];
logic [29:0] dsp_a [0:NLANES-1];
logic [17:0] dsp_b [0:NLANES-1];
logic [47:0] dsp_p [0:NLANES-1];
logic signed [SUM1_W-1:0] sum_s2 [0:3];
logic signed [SUM2_W-1:0] sum_s3 [0:1];
logic signed [SUM3_W-1:0] sum_s4;

integer i;
genvar g;

generate
    for (g = 0; g < NLANES; g = g + 1) begin : G_DSP_LANES
        assign a_lane[g] = vec0[g*IWIDTH +: IWIDTH];
        assign b_lane[g] = vec1[g*IWIDTH +: IWIDTH];
        assign dsp_a[g] = {{(30-IWIDTH){a_lane[g][IWIDTH-1]}}, a_lane[g]};
        assign dsp_b[g] = {{(18-IWIDTH){b_lane[g][IWIDTH-1]}}, b_lane[g]};

        DSP48E2 #(
            .USE_MULT("MULTIPLY"),
            .USE_SIMD("ONE48"),
            .AREG(1),
            .BREG(1),
            .MREG(1),
            .PREG(0),
            .ACASCREG(1),
            .BCASCREG(1),
            .CREG(0),
            .DREG(0),
            .ADREG(0),
            .INMODEREG(0),
            .OPMODEREG(0),
            .ALUMODEREG(0),
            .CARRYINREG(0),
            .CARRYINSELREG(0)
        ) u_dsp (
            .CLK(clk),
            .A(dsp_a[g]),
            .B(dsp_b[g]),
            .C(48'd0),
            .D(27'd0),
            .ACIN(30'd0),
            .BCIN(18'd0),
            .PCIN(48'd0),
            .ALUMODE(4'b0000),
            .INMODE(5'b00000),
            .OPMODE(9'b000000101),
            .CARRYINSEL(3'b000),
            .CARRYIN(1'b0),
            .CEA1(1'b1),
            .CEA2(1'b1),
            .CEB1(1'b1),
            .CEB2(1'b1),
            .CEC(1'b1),
            .CED(1'b1),
            .CEAD(1'b1),
            .CEINMODE(1'b1),
            .CECTRL(1'b1),
            .CEALUMODE(1'b1),
            .CECARRYIN(1'b1),
            .CEM(1'b1),
            .CEP(1'b1),
            .RSTA(rst),
            .RSTB(rst),
            .RSTC(rst),
            .RSTD(rst),
            .RSTINMODE(rst),
            .RSTCTRL(rst),
            .RSTALUMODE(rst),
            .RSTALLCARRYIN(rst),
            .RSTM(rst),
            .RSTP(rst),
            .P(dsp_p[g]),
            .ACOUT(),
            .BCOUT(),
            .PCOUT(),
            .CARRYCASCOUT(),
            .CARRYOUT(),
            .MULTSIGNOUT(),
            .OVERFLOW(),
            .UNDERFLOW(),
            .PATTERNDETECT(),
            .PATTERNBDETECT(),
            .XOROUT()
        );
    end
endgenerate

always_ff @(posedge clk) begin
    if (rst) begin
        valid_pipe <= '0;

        for (i = 0; i < 4; i = i + 1)
            sum_s2[i] <= '0;
        for (i = 0; i < 2; i = i + 1)
            sum_s3[i] <= '0;
        sum_s4 <= '0;
    end else begin
        valid_pipe[0] <= ivalid;
        valid_pipe[1] <= valid_pipe[0];
        valid_pipe[2] <= valid_pipe[1];
        valid_pipe[3] <= valid_pipe[2];
        valid_pipe[4] <= valid_pipe[3];

        if (valid_pipe[1]) begin
            sum_s2[0] <= $signed(dsp_p[0][PROD_W-1:0]) + $signed(dsp_p[1][PROD_W-1:0]);
            sum_s2[1] <= $signed(dsp_p[2][PROD_W-1:0]) + $signed(dsp_p[3][PROD_W-1:0]);
            sum_s2[2] <= $signed(dsp_p[4][PROD_W-1:0]) + $signed(dsp_p[5][PROD_W-1:0]);
            sum_s2[3] <= $signed(dsp_p[6][PROD_W-1:0]) + $signed(dsp_p[7][PROD_W-1:0]);
        end

        if (valid_pipe[2]) begin
            sum_s3[0] <= $signed(sum_s2[0]) + $signed(sum_s2[1]);
            sum_s3[1] <= $signed(sum_s2[2]) + $signed(sum_s2[3]);
        end

        if (valid_pipe[3]) begin
            sum_s4 <= $signed(sum_s3[0]) + $signed(sum_s3[1]);
        end
    end
end

always_comb begin
    if (OWIDTH >= SUM3_W)
        result = {{(OWIDTH-SUM3_W){sum_s4[SUM3_W-1]}}, sum_s4};
    else
        result = sum_s4[OWIDTH-1:0];
end

assign ovalid = valid_pipe[4];

/******* Your code ends here ********/

endmodule