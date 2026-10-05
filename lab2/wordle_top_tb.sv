`timescale 1ns / 1ps

module wordle_top_tb();

localparam int CLK_PERIOD = 2;
localparam int NUM_LETTERS = 4;
localparam int WORD_WIDTH  = NUM_LETTERS * 8;
localparam int RSLT_WIDTH  = NUM_LETTERS * 2;
localparam int MAX_GUESSES = 6;
localparam int GUESS_CNTW  = $clog2(MAX_GUESSES) + 1;
localparam int DICT_SIZE   = 1024;
localparam int ADDR_WIDTH  = $clog2(DICT_SIZE);

logic clk;
logic rstn;
logic [ADDR_WIDTH-1:0] i_ref_word_idx;
logic [WORD_WIDTH-1:0] i_guess_word;
logic [GUESS_CNTW-1:0] i_guess_id;

logic o_ready;
logic [RSLT_WIDTH-1:0] o_result;
logic [GUESS_CNTW-1:0] o_guess_count;
logic [1:0] o_game_status;

logic sim_failed;

wordle_top dut (
    .clk(clk),
    .rstn(rstn),
    .i_ref_word_idx(i_ref_word_idx),
    .i_guess_word(i_guess_word),
    .i_guess_id(i_guess_id),
    .o_ready(o_ready),
    .o_result(o_result),
    .o_guess_count(o_guess_count),
    .o_game_status(o_game_status)
);

// clock
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ---------- tiny TB helpers (no Wordle 계산!) ----------
task automatic tb_fail(input string msg);
begin
    sim_failed = 1'b1;
    $display("[TB] FAIL: %s (t=%0t)", msg, $time);
end
endtask

task automatic expect_eq(input string tag, input logic [31:0] got, input logic [31:0] exp);
begin
    if (got !== exp) tb_fail($sformatf("%s got=%0h exp=%0h", tag, got, exp));
end
endtask

task automatic wait_posedges(input int n);
    repeat (n) @(posedge clk);
endtask

// wait until guess count goes to the exp val i.e. receive guess
task automatic wait_count(input logic [GUESS_CNTW-1:0] target, input int timeout, input string ctx);
    int k;
begin
    k = 0;
    while ((o_guess_count !== target) && (k < timeout)) begin
        @(posedge clk);
        k++;
    end
    if (o_guess_count !== target) tb_fail($sformatf("%s timeout waiting count=%0d (got %0d)", ctx, target, o_guess_count));
end
endtask

// update guess and compare result
task automatic do_guess_hardcheck(
    input [WORD_WIDTH-1:0] gw,
    input [GUESS_CNTW-1:0] gid,
    input [GUESS_CNTW-1:0] exp_cnt,
    input [RSLT_WIDTH-1:0] exp_res,
    input [1:0] exp_stat,
    input string ctx
);
begin
    // drive on negedge to avoid race
    @(negedge clk);
    i_guess_word = gw;
    i_guess_id   = gid;

    // wait until DUT actually accepted it (count hits exp_cnt)
    wait_count(exp_cnt, 300, {ctx, " wait_count"});

    // give 1-2 cycles for result/status to settle for multi-cycle DUTs
    wait_posedges(2);

    expect_eq({ctx, " o_guess_count"}, o_guess_count, exp_cnt);
    expect_eq({ctx, " o_result"},      o_result,      exp_res);
    expect_eq({ctx, " o_game_status"}, o_game_status, exp_stat);

    // if game over, ready must be 0
    if ((exp_stat == 2'b11) || (exp_stat == 2'b10)) begin
        if (o_ready !== 1'b0) tb_fail({ctx, " o_ready should be 0 in game over"});
    end
end
endtask

// invalide guess id : eq or less than prev
task automatic invalid_id_should_not_change(
    input [WORD_WIDTH-1:0] gw,
    input [GUESS_CNTW-1:0] bad_gid,
    input string ctx
);
    logic [RSLT_WIDTH-1:0] prev_res;
    logic [GUESS_CNTW-1:0] prev_cnt;
    logic [1:0] prev_stat;
begin
    @(posedge clk); #1;
    prev_res  = o_result;
    prev_cnt  = o_guess_count;
    prev_stat = o_game_status;

    @(negedge clk);
    i_guess_word = gw;
    i_guess_id   = bad_gid;

    repeat (5) begin
        @(posedge clk); #1;
        if (o_result      !== prev_res)  tb_fail({ctx, " invalid-id changed o_result"});
        if (o_guess_count !== prev_cnt)  tb_fail({ctx, " invalid-id changed o_guess_count"});
        if (o_game_status !== prev_stat) tb_fail({ctx, " invalid-id changed o_game_status"});
    end
end
endtask

// restart: i_guess_id=0，wait till count = 0 status = ONGOING
task automatic restart_game(input [ADDR_WIDTH-1:0] idx, input string ctx);
begin
     @(negedge clk);
    rstn = 1'b0;
    i_ref_word_idx = idx;
    i_guess_word   = '0;
    i_guess_id     = '0;

    repeat (3) @(posedge clk);
    @(negedge clk);
    rstn = 1'b1;
    repeat (5) @(posedge clk);
    
//    $display("[TB] %s idx=%0d ref_word(raw)=%h", ctx, idx, dut.fsm_inst.ref_word);

    expect_eq({ctx, " status after restart"}, o_game_status, 2'b00);
    expect_eq({ctx, " count after restart"},  o_guess_count, '0);

    if (o_ready !== 1'b1) tb_fail({ctx," o_ready should be 1 after reset"});

    end
endtask

task automatic restart_by_guessid0(input [ADDR_WIDTH-1:0] idx, input string ctx);
    begin
        @(negedge clk);
        i_ref_word_idx = idx;
        i_guess_word   = '0;
        i_guess_id     = '0;   // spec restart condition
    
        wait_posedges(6);
    
        expect_eq({ctx, " count after restart"},  o_guess_count, '0);
        expect_eq({ctx, " status after restart"}, o_game_status, 2'b00);
        if (o_ready !== 1'b1) tb_fail({ctx, " o_ready should be 1 after restart"});
    end
endtask

// ---------- main ----------
initial begin
    sim_failed = 1'b0;

    rstn           = 1'b0;
    i_ref_word_idx = '0;
    i_guess_word   = '0;
    i_guess_id     = '0;

    #(5*CLK_PERIOD);
    rstn = 1'b1;

    // =========================================================
    // CASE1: idx=45 -> "furl" (from your ROM)
    // expected results (hardcoded):
    // "farm" -> 0x44, "fork" -> 0x44, "fury" -> 0x54, "furn" -> 0x54, "furl" -> 0x55 WIN
    // =========================================================
    restart_game(10'd45, "case1 start");

    do_guess_hardcheck(32'h6661726d /*farm*/, 1, 1, 8'h44, 2'b00, "case1 r1");
    invalid_id_should_not_change(32'h7a7a7a7a /*zzzz*/, 1, "case1 invalid-id (repeat 1)");

    do_guess_hardcheck(32'h666f726b /*fork*/, 2, 2, 8'h44, 2'b00, "case1 r2");
    do_guess_hardcheck(32'h66757279 /*fury*/, 3, 3, 8'h54, 2'b00, "case1 r3");
    do_guess_hardcheck(32'h6675726e /*furn*/, 4, 4, 8'h54, 2'b00, "case1 r4");

    do_guess_hardcheck(32'h6675726c /*furl*/, 5, 5, 8'h55, 2'b11, "case1 r5 WIN");

    // WIN hold: ready must stay 0
    repeat (5) begin
        @(posedge clk); #1;
        if (o_ready !== 1'b0) tb_fail("case1 WIN but o_ready asserted");
    end
    
    restart_by_guessid0(10'd45, "case1 restart by guess_id=0");
    
    do_guess_hardcheck(32'h6661726d /*farm*/, 1, 1, 8'h44, 2'b00, "case1 after restart r1");


    // =========================================================
    // CASE2: idx=207 -> "loom"
    // 6 wrong guesses -> LOSE on 6th
    // expected (hardcoded):
    // farm -> 0x01, fork -> 0x10, test -> 0x00, pare -> 0x00, snow -> 0x04, boom -> 0x15 LOSE
    // =========================================================
    restart_game(10'd207, "case2 start");

    do_guess_hardcheck(32'h6661726d /*farm*/, 1, 1, 8'h01, 2'b00, "case2 r1");
    do_guess_hardcheck(32'h666f726b /*fork*/, 2, 2, 8'h10, 2'b00, "case2 r2");
    do_guess_hardcheck(32'h74657374 /*test*/, 3, 3, 8'h00, 2'b00, "case2 r3");
    do_guess_hardcheck(32'h70617265 /*pare*/, 4, 4, 8'h00, 2'b00, "case2 r4");
    do_guess_hardcheck(32'h736e6f77 /*snow*/, 5, 5, 8'h04, 2'b00, "case2 r5");

    do_guess_hardcheck(32'h626f6f6d /*boom*/, 6, 6, 8'h15, 2'b10, "case2 r6 LOSE");

    // LOSE hold: ready must stay 0
    repeat (5) begin
        @(posedge clk); #1;
        if (o_ready !== 1'b0) tb_fail("case2 LOSE but o_ready asserted");
    end

    // restart after LOSE
    restart_game(10'd207, "case2 restart after LOSE");
    
    // =========================================================
    // CASE3: idx=772 -> "doom" (WIN in 4) + spec restart check
    // guesses: died, loom, zoom, doom
    // expected:
    // died -> 0x01, loom -> 0x54, zoom -> 0x54, doom -> 0x55 WIN
    // =========================================================
    restart_game(10'd772, "case3 start (doom)");

    do_guess_hardcheck(32'h64696564 /*died*/, 1, 1, 8'h40, 2'b00, "case3 r1");
    invalid_id_should_not_change(32'h7a7a7a7a /*zzzz*/, 1, "case3 invalid-id (repeat 1)");

    do_guess_hardcheck(32'h6c6f6f6d /*loom*/, 2, 2, 8'h15, 2'b00, "case3 r2");
    do_guess_hardcheck(32'h7a6f6f6d /*zoom*/, 3, 3, 8'h15, 2'b00, "case3 r3");
    do_guess_hardcheck(32'h646f6f6d /*doom*/, 4, 4, 8'h55, 2'b11, "case3 r4 WIN");

    // spec restart after WIN (guess_id=0)
    restart_by_guessid0(10'd772, "case3 restart by guess_id=0");
    do_guess_hardcheck(32'h64696564 /*died*/, 1, 1, 8'h40, 2'b00, "case3 after spec restart r1");
    
    // =========================================================
    // CASE4: idx=297 -> "make" (LOSE on 6th) + spec restart check
    // guesses: grip, pare, loop, purl, cure, sink
    // expected:    
    // grip -> 0x00, pare -> 0x44, loop -> 0x00, purl -> 0x00, cure -> 0x40, sink -> 0x80 LOSE
    // =========================================================
    restart_game(10'd297, "case4 start (make lose)");

    do_guess_hardcheck(32'h67726970 /*grip*/, 1, 1, 8'h00, 2'b00, "case4 r1");
    do_guess_hardcheck(32'h70617265 /*pare*/, 2, 2, 8'h11, 2'b00, "case4 r2");
    do_guess_hardcheck(32'h6c6f6f70 /*loop*/, 3, 3, 8'h00, 2'b00, "case4 r3");
    do_guess_hardcheck(32'h7075726c /*purl*/, 4, 4, 8'h00, 2'b00, "case4 r4");
    do_guess_hardcheck(32'h63757265 /*cure*/, 5, 5, 8'h01, 2'b00, "case4 r5");
    do_guess_hardcheck(32'h73696e6b /*sink*/, 6, 6, 8'h02, 2'b10, "case4 r6 LOSE");

    // spec restart after LOSE (guess_id=0)
    restart_by_guessid0(10'd297, "case4 restart by guess_id=0");
    do_guess_hardcheck(32'h67726970 /*grip*/, 1, 1, 8'h00, 2'b00, "case4 after spec restart r1");
    
    // =========================================================
    // CASE5: idx=497 -> "toll" (dup-letter stress) WIN in 4 + spec restart
    // expected:
    // tool -> 0x45, loot -> 0x86, loll -> 0x54, toll -> 0x55 WIN
    // =========================================================
    restart_game(10'd497, "case5 start (toll dup-stress)");

    do_guess_hardcheck(32'h746f6f6c /*tool*/, 1, 1, 8'h51, 2'b00, "case5 r1");
    do_guess_hardcheck(32'h6c6f6f74 /*loot*/, 2, 2, 8'h92, 2'b00, "case5 r2");
    do_guess_hardcheck(32'h6c6f6c6c /*loll*/, 3, 3, 8'h15, 2'b00, "case5 r3");
    do_guess_hardcheck(32'h746f6c6c /*toll*/, 4, 4, 8'h55, 2'b11, "case5 r4 WIN");

    restart_by_guessid0(10'd497, "case5 restart by guess_id=0");
    do_guess_hardcheck(32'h746f6f6c /*tool*/, 1, 1, 8'h51, 2'b00, "case5 after spec restart r1");

    if (sim_failed) $display("TEST FAILED!");
    else            $display("TEST PASSED!");
    $stop;
end

endmodule
