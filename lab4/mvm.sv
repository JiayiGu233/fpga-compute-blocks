/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 4                                               */
/* Matrix Vector Multiplication (MVM) Module           */
/*******************************************************/

module mvm # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32,
    parameter MEM_DATAW = IWIDTH * 8,
    parameter VEC_MEM_DEPTH = 256,
    parameter VEC_ADDRW = $clog2(VEC_MEM_DEPTH),
    parameter MAT_MEM_DEPTH = 512,
    parameter MAT_ADDRW = $clog2(MAT_MEM_DEPTH),
    // Default is used for the bonus throughput evaluation.
    // For M=N=512 with MAT_MEM_DEPTH=512, NUM_OLANES>=64 is required so that each
    // matrix memory can hold (N/8)*(M/NUM_OLANES) = 64*(512/NUM_OLANES) words.
    parameter NUM_OLANES = 48
)(
    input clk,
    input rst,
    input [MEM_DATAW-1:0] i_vec_wdata,
    input [VEC_ADDRW-1:0] i_vec_waddr,
    input i_vec_wen,
    input [MEM_DATAW-1:0] i_mat_wdata,
    input [MAT_ADDRW-1:0] i_mat_waddr,
    input [NUM_OLANES-1:0] i_mat_wen,
    input i_start,
    input [VEC_ADDRW-1:0] i_vec_start_addr,
    input [VEC_ADDRW:0] i_vec_num_words,
    input [MAT_ADDRW-1:0] i_mat_start_addr,
    input [MAT_ADDRW:0] i_mat_num_rows_per_olane,
    output o_busy,
    output [OWIDTH*NUM_OLANES-1:0] o_result,
    output o_valid
);

/******* Your code starts here *******/
localparam int CTRL_TO_DOT   = 2;
localparam int DOT_LATENCY   = 5;
localparam int CTRL_TO_ACCUM = CTRL_TO_DOT + DOT_LATENCY;

logic [VEC_ADDRW-1:0] vec_raddr_ctrl;
logic [MAT_ADDRW-1:0] mat_raddr_ctrl;
logic accum_first_ctrl;
logic accum_last_ctrl;
logic ctrl_ovalid;
logic ctrl_busy;
logic [MEM_DATAW-1:0] vec_rdata;
(* max_fanout = 16 *) logic [MEM_DATAW-1:0] vec_rdata_d;
logic [MEM_DATAW-1:0] mat_rdata [0:NUM_OLANES-1];
logic [MEM_DATAW-1:0] mat_rdata_d [0:NUM_OLANES-1];
logic signed [OWIDTH-1:0] dot_result [0:NUM_OLANES-1];
logic dot_ovalid [0:NUM_OLANES-1];
logic signed [OWIDTH-1:0] accum_result [0:NUM_OLANES-1];
logic accum_ovalid [0:NUM_OLANES-1];
logic [CTRL_TO_ACCUM-1:0] first_pipe;
logic [CTRL_TO_ACCUM-1:0] last_pipe;
logic [CTRL_TO_ACCUM-1:0] valid_pipe;
logic dot_ivalid;

integer i;
genvar g;

ctrl #(
    .VEC_ADDRW(VEC_ADDRW),
    .MAT_ADDRW(MAT_ADDRW),
    .VEC_SIZEW(VEC_ADDRW + 1),
    .MAT_SIZEW(MAT_ADDRW + 1)
) u_ctrl (
    .clk(clk),
    .rst(rst),
    .start(i_start),
    .vec_start_addr(i_vec_start_addr),
    .vec_num_words(i_vec_num_words),
    .mat_start_addr(i_mat_start_addr),
    .mat_num_rows_per_olane(i_mat_num_rows_per_olane),
    .vec_raddr(vec_raddr_ctrl),
    .mat_raddr(mat_raddr_ctrl),
    .accum_first(accum_first_ctrl),
    .accum_last(accum_last_ctrl),
    .ovalid(ctrl_ovalid),
    .busy(ctrl_busy)
);

mem #(
    .DATAW(MEM_DATAW),
    .DEPTH(VEC_MEM_DEPTH)
) u_vec_mem (
    .clk(clk),
    .wdata(i_vec_wdata),
    .waddr(i_vec_waddr),
    .wen(i_vec_wen),
    .raddr(vec_raddr_ctrl),
    .rdata(vec_rdata)
);

generate
    for (g = 0; g < NUM_OLANES; g = g + 1) begin : G_LANES
        mem #(
            .DATAW(MEM_DATAW),
            .DEPTH(MAT_MEM_DEPTH)
        ) u_mat_mem (
            .clk(clk),
            .wdata(i_mat_wdata),
            .waddr(i_mat_waddr),
            .wen(i_mat_wen[g]),
            .raddr(mat_raddr_ctrl),
            .rdata(mat_rdata[g])
        );

        dot8 #(
            .IWIDTH(IWIDTH),
            .OWIDTH(OWIDTH)
        ) u_dot8 (
            .clk(clk),
            .rst(rst),
            .vec0(vec_rdata_d),
            .vec1(mat_rdata_d[g]),
            .ivalid(dot_ivalid),
            .result(dot_result[g]),
            .ovalid(dot_ovalid[g])
        );

        accum #(
            .DATAW(OWIDTH),
            .ACCUMW(OWIDTH)
        ) u_accum (
            .clk(clk),
            .rst(rst),
            .data(dot_result[g]),
            .ivalid(dot_ovalid[g]),
            .first(first_pipe[CTRL_TO_ACCUM-1]),
            .last(last_pipe[CTRL_TO_ACCUM-1]),
            .result(accum_result[g]),
            .ovalid(accum_ovalid[g])
        );

        assign o_result[g*OWIDTH +: OWIDTH] = accum_result[g];
    end
endgenerate

always_ff @(posedge clk) begin
    if (rst) begin
        vec_rdata_d <= '0;
        for (i = 0; i < NUM_OLANES; i = i + 1) begin
            mat_rdata_d[i] <= '0;
        end

        first_pipe <= '0;
        last_pipe  <= '0;
        valid_pipe <= '0;
    end else begin
        vec_rdata_d <= vec_rdata;
        for (i = 0; i < NUM_OLANES; i = i + 1) begin
            mat_rdata_d[i] <= mat_rdata[i];
        end

        first_pipe[0] <= accum_first_ctrl & ctrl_ovalid;
        last_pipe[0]  <= accum_last_ctrl  & ctrl_ovalid;
        valid_pipe[0] <= ctrl_ovalid;

        for (i = 1; i < CTRL_TO_ACCUM; i = i + 1) begin
            first_pipe[i] <= first_pipe[i-1];
            last_pipe[i]  <= last_pipe[i-1];
            valid_pipe[i] <= valid_pipe[i-1];
        end
    end
end

assign dot_ivalid = valid_pipe[CTRL_TO_DOT-1];
assign o_valid = accum_ovalid[0];
assign o_busy = ctrl_busy | (|valid_pipe);

/******* Your code ends here ********/

endmodule
