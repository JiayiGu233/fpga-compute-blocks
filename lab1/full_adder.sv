/*******************************************************/
/* ECE 327/627: Digital Hardware Systems - Winter 2026 */
/* Lab 1 - Part 1                                      */
/* Full adder module                                   */
/*******************************************************/

module full_adder (
    input a,    // First operand bit
    input b,    // Second operand bit
    input cin,  // Input Carry bit
    output s,   // Output sum bit
    output cout // Output carry bit
);

/******* Your code starts here *******/
logic s0;
logic cout0;

always_comb begin
 s0 = a ^ b ^ cin;
 cout0 = (a&b)|(a&cin)|(b&cin);
end

assign s = s0;
assign cout = cout0;

/******* Your code ends here ********/

endmodule
