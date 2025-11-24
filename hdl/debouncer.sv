`timescale 1ns / 1ps
`default_nettype none

//written in lecture!
//debounce_2.sv is a different attempt at this done after class with a few students
module  debouncer #(parameter CLK_PERIOD_NS = 10,
                    parameter DEBOUNCE_TIME_MS = 5
                    )
    (   input wire clk,
        input wire rst,
        input wire dirty,
        output logic clean
    );
    //you will likely need to cast this:
    localparam COUNTER_MAX = int'($ceil(DEBOUNCE_TIME_MS*1_000_000/CLK_PERIOD_NS));
    localparam COUNTER_SIZE = $clog2(COUNTER_MAX);
    logic [COUNTER_SIZE-1:0] counter;
    logic current; //register holds current output
    logic old_dirty;
    assign clean = current;

    always_ff @(posedge clk)begin
        if (rst)begin
            counter <= 0;
            current <= dirty;
            old_dirty <= dirty;
        end else begin
            if (counter == COUNTER_MAX-1)begin
                current <= old_dirty;
                counter <= 0;
            end else if (dirty == old_dirty) begin
                counter <= counter +1;
            end else begin
                counter <= 0;
            end
        end
        old_dirty <= dirty;
    end
endmodule

`default_nettype wire