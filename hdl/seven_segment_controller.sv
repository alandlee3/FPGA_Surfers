`default_nettype none
module seven_segment_controller #(parameter COUNT_PERIOD = 100000)
    (   input wire           clk,
        input wire           rst,
        input wire [31:0]    val,
        output logic[6:0]    cat,
        output logic[7:0]    an
    );
    logic [7:0]   segment_state;
    logic [31:0]  segment_counter;
    logic [3:0]   sel_values;
    logic [6:0]   led_out;
 
    //TODO: wire up sel_values (-> x) with your input, val
    //Note that x is a 4 bit input, and val is 32 bits wide
    //Adjust accordingly, based on what you know re. which digits
    //are displayed when...
    always_comb begin
        sel_values = 4'b0;
        for (int i = 0; i < 8; i = i + 1) begin
            sel_values += segment_state[i] ? val[i*4+:4] : 4'b0;
        end
    end

    bto7s mbto7s (.x(sel_values), .s(led_out));
    assign cat = ~led_out; //<--note this inversion is needed
    assign an = ~segment_state; //note this inversion is needed
 
    always_ff @(posedge clk)begin
        if (rst)begin
            segment_state <= 8'b0000_0001;
            segment_counter <= 32'b0;
        end else begin
            if (segment_counter == COUNT_PERIOD) begin
                segment_counter <= 32'd0;
                segment_state <= {segment_state[6:0],segment_state[7]};
            end else begin
                segment_counter <= segment_counter +1;
            end
        end
    end
endmodule // seven_segment_controller
 
/* drop your bto7s module from lab 1 here! */
module bto7s(
        input wire [3:0]   x,
        output logic [6:0] s
        );
  logic [15:0] num;
  assign num = 16'b1 << x;

  assign s[0] = num[0] || num[2] || num[3] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[12] ||num[14] ||num[15];
  assign s[1] = num[0] || num[1] || num[2] || num[3] || num[4] || num[7] || num[8] || num[9] || num[10] || num[13];
  assign s[2] = num[0] || num[1] || num[3] || num[4] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[11] || num[13];
  assign s[3] = num[0] || num[2] || num[3] || num[5] || num[6] || num[8] || num[9] || num[11] || num[12] || num[13] || num[14];
  assign s[4] = num[0] || num[2] || num[6] || num[8] || num[10] || num[11] || num[12] || num[13] || num[14] || num[15];
  assign s[5] = num[0] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[12] || num[14] || num[15];
  assign s[6] = num[2] || num[3] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[13] || num[14] || num[15];
endmodule
 
`default_nettype wire
