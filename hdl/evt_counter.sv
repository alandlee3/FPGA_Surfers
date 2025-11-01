`default_nettype none
module evt_counter 
#(
    parameter MAX_COUNT,
    parameter WIDTH = 16
) (
        input wire          clk,
        input wire          rst,
        input wire          evt,
        output logic[WIDTH-1:0]  count
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            count <= 0;
        end else begin
            if(count + evt == MAX_COUNT) begin
                count <= 0;
            end else begin
                count <= count + evt;
            end
        end
    end
endmodule
`default_nettype wire