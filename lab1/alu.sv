/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 1 - Part 3                                      */
/* Shift-Left, Add, Subract ALU module                 */
/*******************************************************/

module alu # (
    parameter DATAW = 32 // Bitwidth of ALU operands
)(
    input  clk,                   // Input clock signal
    input  rstn,                  // Active-low reset signal
    input  [DATAW-1:0] i_dataa,   // First operand (A)
    input  [DATAW-1:0] i_datab,   // Second operand (B)
    input  [1:0] i_op,            // Operation code (00: A+B, 01: A-B, 10: A*B, 11: A^2)
    output [DATAW-1:0] o_result   // ALU output
);

// Remember that you are required to register all inputs and outputs of the ALU and use 
// the adder/subtractor module you implemented in Part 2 of this lab.

/******* Your code starts here *******/
logic [DATAW-1:0] res;
logic [DATAW-1:0] addSubRes; 
logic [DATAW-1:0] a, b;
logic [1:0] op;

add_sub # (DATAW) addSub (a, b, op[0], addSubRes);

always_ff @ (posedge clk) begin
 a <= i_dataa;
 b <= i_datab;
 op <= i_op;
 if (!rstn) begin
    res <= 0;
    a <= 0;
    b <= 0;
    op <= 0;
 end else begin
    case(op)
        2'b00: begin 
            res <= addSubRes;
        end
        2'b01: begin
            res <= addSubRes;
        end
        2'b10: begin
            res <= a * b;
        end
        2'b11: begin
            res <= a * a;
        end
    endcase
  end      
end

assign o_result = res;
/******* Your code ends here ********/

endmodule
