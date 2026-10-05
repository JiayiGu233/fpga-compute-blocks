/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 1 - Part 2                                      */
/* Multi-bit adder/subtractor module                   */
/*******************************************************/

module add_sub # (
    parameter DATAW = 2 // Bitwidth of adder/subtractor operands
)(
    input  [DATAW-1:0] i_dataa,  // First operand (A)
    input  [DATAW-1:0] i_datab,  // Second operand (B)
    input  i_op,                 // Operation (0: A+B, 1: A-B)
    output [DATAW-1:0] o_result  // Addition/Subtraction result
);

/******* Your code starts here *******/
logic [DATAW:0] c;

assign c[0] = i_op;

genvar i;
generate
for (i=0; i<= DATAW-1; i = i + 1)
begin: gen_adders
    full_adder add_inst(
        .a(i_dataa[i]), .b(i_datab[i] ^ i_op), .cin(c[i]), .s(o_result[i]), .cout(c[i+1])
    );
end
endgenerate

/******* Your code ends here ********/

endmodule
