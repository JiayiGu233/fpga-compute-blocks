/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 4                                               */
/* Accumulator Module                                  */
/*******************************************************/

module accum # (
    parameter DATAW = 32,
    parameter ACCUMW = 32
)(
    input  clk,
    input  rst,
    input  signed [DATAW-1:0] data,
    input  ivalid,
    input  first,
    input  last,
    output signed [ACCUMW-1:0] result,
    output ovalid
);

/******* Your code starts here *******/
logic signed [ACCUMW-1:0] r_result;
logic r_ovalid;
(* use_dsp = "yes" *) logic signed [ACCUMW-1:0] add_res;
assign add_res = r_result + $signed(data);

always_ff @(posedge clk) begin
    if (rst) begin
        r_result <= '0;
        r_ovalid <= 1'b0;
    end else begin
        r_ovalid <= 1'b0;

        if (ivalid) begin
            if (first)
                r_result <= $signed(data);
            else
                r_result <= add_res;

            if (last)
                r_ovalid <= 1'b1;
        end
    end
end

assign result = r_result;
assign ovalid = r_ovalid;
/******* Your code ends here ********/

endmodule
