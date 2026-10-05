/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 2                                               */
/* Wordle FSM Module                                   */
/*******************************************************/
module wordle_fsm #(
    parameter NUM_LETTERS = 4,                      // Word size in letters
    parameter WORD_WIDTH = NUM_LETTERS * 8,         // Word bitwidth
    parameter RSLT_WIDTH = NUM_LETTERS * 2,         // Result bitwidth
    parameter MAX_GUESSES = 6,                      // Maximum number of allowed guesses
    parameter GUESS_CNTW = $clog2(MAX_GUESSES) + 1  // Bitwidth of guess counter
)(
    input clk,                              // Input clock
    input rstn,                             // Input active-low reset
    input [WORD_WIDTH-1:0] i_ref_word,      // Input reference word 
    input [WORD_WIDTH-1:0] i_guess_word,    // Input user guess word
    input [GUESS_CNTW-1:0] i_guess_id,      // Input user guess ID
    output o_ready,                         // Output ready signal (result is valid & ready to accept new guess word)
    output [RSLT_WIDTH-1:0] o_result,       // Output result of a guess (4 letters x 2-bit status: GREEN, YELLOW, GREY)
    output [GUESS_CNTW-1:0] o_guess_count,  // Output number of user guesses so far
    output [1:0] o_game_status              // Output game status (ongoing, user won, user lost)
);
// Declare registers to hold game result, guess count, and status
typedef enum logic [1:0] {GREY = 2'b00, GREEN = 2'b01, YELLOW = 2'b10} color_t;
color_t r_result [0:NUM_LETTERS-1];
logic [GUESS_CNTW-1:0] r_guess_count;
enum logic [1:0] {ONGOING = 2'b00, WIN = 2'b11, LOSE = 2'b10} r_game_status;
/******* Your code starts here *******/
logic [WORD_WIDTH-1:0] ref_word;
logic [WORD_WIDTH-1:0] guess_word;
logic [GUESS_CNTW-1:0] guess_id; 
typedef enum logic [1:0] {INIT = 2'b00, INPUT_WAITING = 2'b01, INPUT_EVAL = 2'b10, GAME_OVER = 2'b11} fsm_state_t;
fsm_state_t state, next_state;
logic [RSLT_WIDTH-1:0] result_vec;
logic receive_valid_guess;
// Output is ready only when waiting for a new guess and the game is ongoing.
assign o_ready = (state == INPUT_WAITING) && (r_game_status == ONGOING);
// Compute a result vector for the current guess/reference words.
function automatic [RSLT_WIDTH-1:0] calc_res(
    input [WORD_WIDTH-1:0] ref_w,
    input [WORD_WIDTH-1:0] guess_w
);
    logic [1:0] res [0:NUM_LETTERS-1];
    logic ref_used [0:NUM_LETTERS-1];
    integer i, j;
    logic found;
    begin
        for (i = 0; i < NUM_LETTERS; i = i + 1) begin
            res[i] = GREY;
            ref_used[i] = 1'b0;
        end
        // Mark greens first (exact matches).
        for (i = 0; i < NUM_LETTERS; i = i + 1) begin
            if (guess_w[i*8 +: 8] == ref_w[i*8 +: 8]) begin
                res[i] = GREEN;
                ref_used[i] = 1'b1;
            end
        end
        // Mark yellows next. Process from rightmost to leftmost so the last
        // occurrence gets priority when duplicates exist.
        for (i = 0; i < NUM_LETTERS; i = i + 1) begin
            if (res[i] != GREEN) begin
                found = 1'b0;
                for (j = NUM_LETTERS -1 ; j >= 0; j = j - 1) begin
                    if (!ref_used[j] && (guess_w[i*8 +: 8] == ref_w[j*8 +: 8]) && !found) begin
                        res[i] = YELLOW;
                        ref_used[j] = 1'b1;
                        found = 1'b1;
                    end
                end
            end
        end
        calc_res = '0;
        for (i = 0; i < NUM_LETTERS; i = i + 1) begin
            calc_res[i*2 +: 2] = res[i];
        end
    end
endfunction
always_comb begin
    receive_valid_guess = (state == INPUT_WAITING) && (i_guess_id > guess_id) && (r_game_status == ONGOING);
    result_vec = calc_res(ref_word, guess_word);
end
always_comb begin
    next_state = state;
    case (state)
        INIT: begin
            next_state = INPUT_WAITING;
        end
        INPUT_WAITING: begin
            if (receive_valid_guess) begin
                next_state = INPUT_EVAL;
            end else begin
                next_state = INPUT_WAITING;
            end
        end
        INPUT_EVAL: begin
            if ((guess_word == ref_word) || (r_guess_count >= MAX_GUESSES)) begin
                next_state = GAME_OVER;
            end else begin
                next_state = INPUT_WAITING;
            end
        end
        GAME_OVER: begin
            if (i_guess_id == '0) begin
                next_state = INIT;
            end else begin
                next_state = GAME_OVER;
            end
        end
        default: next_state = INIT;
    endcase
end
integer i;
always_ff @(posedge clk) begin
    if (!rstn) begin
        state <= INIT;
        ref_word <= '0;
        guess_word <= '0;
        guess_id <= '0;
        r_guess_count <= '0;
        r_game_status <= ONGOING;
        for (i = 0; i < NUM_LETTERS; i = i + 1) begin
            r_result[i] <= GREY;
        end
    end else begin
        state <= next_state;
        if (state == INIT) begin
            ref_word <= i_ref_word;
            guess_word <= '0;
            guess_id <= '0;
            r_guess_count <= '0;
            r_game_status <= ONGOING;
            for (i = 0; i < NUM_LETTERS; i = i + 1) begin
                r_result[i] <= GREY;
            end
        end else begin
            //state is now INPUT_WAITING
            if (receive_valid_guess) begin
                guess_word <= i_guess_word;
                guess_id <= i_guess_id;
                if (r_guess_count < MAX_GUESSES) begin
                    r_guess_count <= r_guess_count + 1'b1;
                end
            end
            //state is now INPUT_EVAL
            if (state == INPUT_EVAL) begin
                for (i = 0; i < NUM_LETTERS; i = i + 1) begin
                    r_result[i] <= color_t'(result_vec[i*2 +: 2]); // cast to the enum type 
                end
                if (guess_word == ref_word) begin
                    r_game_status <= WIN;
                end else if (r_guess_count >= MAX_GUESSES) begin
                    r_game_status <= LOSE;
                end else begin
                    r_game_status <= ONGOING;
                end
            end
        end
    end
end
/******* Your code ends here ********/
// Connect game result, guess count, and status output ports to the declared corresponding registers
genvar j;
generate
    for (j = 0; j < NUM_LETTERS; j = j + 1) begin: assign_result
        // The indexing syntax used below [M+:N] extracts an N-bit slice of a bitvector starting from bit M (i.e., equivalent to [M+N-1:M])
        assign o_result[j*2+:2] = r_result[j];
    end
endgenerate
assign o_guess_count = r_guess_count;
assign o_game_status = r_game_status;
endmodule
