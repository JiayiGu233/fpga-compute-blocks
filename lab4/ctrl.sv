/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 4                                               */
/* MVM Control FSM                                     */
/*******************************************************/

module ctrl # (
    parameter VEC_ADDRW = 8,
    parameter MAT_ADDRW = 9,
    parameter VEC_SIZEW = VEC_ADDRW + 1,
    parameter MAT_SIZEW = MAT_ADDRW + 1
)(
    input  clk,
    input  rst,
    input  start,
    input  [VEC_ADDRW-1:0] vec_start_addr,
    input  [VEC_SIZEW-1:0] vec_num_words,
    input  [MAT_ADDRW-1:0] mat_start_addr,
    input  [MAT_SIZEW-1:0] mat_num_rows_per_olane,
    output logic [VEC_ADDRW-1:0] vec_raddr,
    output logic [MAT_ADDRW-1:0] mat_raddr,
    output logic accum_first,
    output logic accum_last,
    output logic ovalid,
    output logic busy
);

localparam logic STATE_IDLE    = 1'b0;
localparam logic STATE_COMPUTE = 1'b1;

logic state;
logic [VEC_ADDRW-1:0] vec_start_addr_r;
logic [VEC_SIZEW-1:0] vec_num_words_r;
logic [MAT_ADDRW-1:0] mat_start_addr_r;
logic [MAT_SIZEW-1:0] mat_num_rows_per_olane_r;
logic [VEC_SIZEW-1:0] vec_last_idx_r;
logic [MAT_SIZEW-1:0] row_last_idx_r;
logic [VEC_SIZEW-1:0] word_idx;
logic [MAT_SIZEW-1:0] row_idx;
logic [VEC_ADDRW-1:0] vec_addr_r;
logic [MAT_ADDRW-1:0] mat_addr_r;
logic [MAT_ADDRW-1:0] mat_row_base_r;

always_ff @(posedge clk) begin
    if (rst) begin
        state <= STATE_IDLE;
        vec_start_addr_r <= '0;
        vec_num_words_r <= '0;
        mat_start_addr_r <= '0;
        mat_num_rows_per_olane_r <= '0;
        vec_last_idx_r <= '0;
        row_last_idx_r <= '0;
        word_idx <= '0;
        row_idx <= '0;
        vec_addr_r <= '0;
        mat_addr_r <= '0;
        mat_row_base_r <= '0;
    end else begin
        case (state)
            STATE_IDLE: begin
                vec_start_addr_r <= vec_start_addr;
                vec_num_words_r <= vec_num_words;
                mat_start_addr_r <= mat_start_addr;
                mat_num_rows_per_olane_r <= mat_num_rows_per_olane;
                vec_last_idx_r <= (vec_num_words != 0) ? (vec_num_words - 1'b1) : '0;
                row_last_idx_r <= (mat_num_rows_per_olane != 0) ? (mat_num_rows_per_olane - 1'b1) : '0;
                word_idx <= '0;
                row_idx <= '0;
                vec_addr_r <= '0;
                mat_addr_r <= '0;
                mat_row_base_r <= '0;

                if (start) begin
                    state <= STATE_COMPUTE;
                    vec_start_addr_r <= vec_start_addr;
                    vec_num_words_r <= vec_num_words;
                    mat_start_addr_r <= mat_start_addr;
                    mat_num_rows_per_olane_r <= mat_num_rows_per_olane;
                    vec_last_idx_r <= (vec_num_words != 0) ? (vec_num_words - 1'b1) : '0;
                    row_last_idx_r <= (mat_num_rows_per_olane != 0) ? (mat_num_rows_per_olane - 1'b1) : '0;
                    word_idx <= '0;
                    row_idx <= '0;
                    vec_addr_r <= vec_start_addr;
                    mat_row_base_r <= mat_start_addr;
                    mat_addr_r <= mat_start_addr;
                end
            end

            STATE_COMPUTE: begin
                if (word_idx == vec_last_idx_r) begin
                    // Finished current row
                    if (row_idx == row_last_idx_r) begin
                        state <= STATE_IDLE;
                        word_idx <= '0;
                        row_idx <= '0;
                        vec_addr_r <= '0;
                        mat_addr_r <= '0;
                        mat_row_base_r <= '0;
                    end else begin
                        row_idx <= row_idx + 1'b1;
                        word_idx <= '0;
                        vec_addr_r <= vec_start_addr_r;
                        mat_row_base_r <= mat_row_base_r + vec_num_words_r;
                        mat_addr_r <= mat_row_base_r + vec_num_words_r;
                    end
                end else begin
                    word_idx <= word_idx + 1'b1;
                    vec_addr_r <= vec_addr_r + 1'b1;
                    mat_addr_r <= mat_addr_r + 1'b1;
                end
            end
        endcase
    end
end

always_comb begin
    vec_raddr = '0;
    mat_raddr = '0;
    accum_first = 1'b0;
    accum_last = 1'b0;
    ovalid = 1'b0;
    busy = 1'b0;

    if (state == STATE_COMPUTE) begin
        vec_raddr = vec_addr_r;
        mat_raddr = mat_addr_r;
        accum_first = (word_idx == 0);
        accum_last = (word_idx == vec_last_idx_r);
        ovalid = 1'b1;
        busy = 1'b1;
    end
end

endmodule
