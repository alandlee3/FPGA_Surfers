`timescale 1ns / 1ps
`default_nettype none

module command_fifo #(parameter DEPTH=16, parameter WIDTH=16)(
        input wire clk,
        input wire rst,
        input wire write,
        input wire [WIDTH-1:0] command_in,
        output logic full,

        output logic [WIDTH-1:0] command_out,
        input wire read,
        output logic empty
    );

    localparam LOG_DEPTH = $clog2(DEPTH);

    logic [LOG_DEPTH-1:0]   write_pointer;
    logic [LOG_DEPTH-1:0]   read_pointer;
    logic [WIDTH-1:0] fifo [DEPTH-1:0]; //makes BRAM with one unpacked and one packed dimension

    assign full = (write_pointer + 1'b1) == read_pointer;
    assign empty = (write_pointer == read_pointer);

    always_ff @( posedge clk ) begin 
        if(rst) begin
            write_pointer <= 0;
            read_pointer <= 0;
        end else begin
            if (write & (!full | read) ) begin
                // have room to write!
                fifo[write_pointer] <= command_in;
                write_pointer <= write_pointer + 1'b1;
            end

            if (read & !(empty)) begin
                read_pointer <= read_pointer + 1'b1;
            end
        end
    end

    always_comb begin
        command_out = fifo[read_pointer];
    end



endmodule
`default_nettype wire
