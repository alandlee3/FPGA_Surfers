`default_nettype none
module center_of_mass (
        input wire clk,
        input wire rst,
        input wire [10:0] pixel_x,
        input wire [9:0]  pixel_y,
        input wire pixel_valid,
        input wire calculate,
        output logic [10:0] com_x,
        output logic [9:0] com_y,
        output logic com_valid
    );
    
    // assign com_valid = 0;
    logic [31:0] total_x;
    logic [31:0] total_y;
    logic [31:0] num_x;
    logic [31:0] num_y;
    logic [31:0] x_quotient, x_rem;
    logic [31:0] y_quotient, y_rem;
    logic x_valid, y_valid, x_error, y_error, x_busy, y_busy;
    logic x_in_valid, y_in_valid;

    divider roger
                    (   .clk(clk),
                        .rst(rst),
                        .dividend(total_x),
                        .divisor(num_x),
                        .data_in_valid(x_in_valid),
                        .quotient(x_quotient),
                        .remainder(x_rem),
                        .data_out_valid(x_valid),
                        .error(x_error),
                        .busy(x_busy)
                    );

    divider roger_y
                    (   .clk(clk),
                        .rst(rst),
                        .dividend(total_y),
                        .divisor(num_y),
                        .data_in_valid(y_in_valid),
                        .quotient(y_quotient),
                        .remainder(y_rem),
                        .data_out_valid(y_valid),
                        .error(y_error),
                        .busy(y_busy)
                    );

    enum{SUMMING, WAITINGXY, WAITINGX, WAITINGY, DONE} state;
    always_ff @(posedge clk) begin
        if (rst) begin
            total_x <= 0;
            total_y <= 0;
            num_x <= 0;
            num_y <= 0;
            state <= SUMMING;
            com_valid <= 0;
        end else begin
            case(state)
                SUMMING: begin
                    if (pixel_valid) begin
                        total_x <= total_x + pixel_x;
                        total_y <= total_y + pixel_y;
                        num_x <= num_x + 1;
                        num_y <= num_y + 1;
                    end else if (calculate && num_x != 0 && num_y != 0) begin
                        state <= WAITINGXY;
                        x_in_valid <= 1;
                        y_in_valid <= 1;
                    end
                end
                WAITINGXY: begin
                    x_in_valid <= 0;
                    y_in_valid <= 0;
                    if (y_valid && x_valid) begin
                        state <= DONE;
                        com_valid <= 1;
                        com_x <= x_quotient;
                        com_y <= y_quotient;
                    end else if (y_valid) begin
                        state <= WAITINGX;
                        com_y <= y_quotient;
                    end else if (x_valid) begin
                        state <= WAITINGY;
                        com_x <= x_quotient;
                    end
                end
                WAITINGX: begin
                    if (x_valid) begin
                        state <= DONE;
                        com_valid <= 1;
                        com_x <= x_quotient;
                    end
                end
                WAITINGY: begin
                    if (y_valid) begin
                        state <= DONE;
                        com_valid <= 1;
                        com_y <= y_quotient;
                    end
                end
                DONE: begin // single state
                    num_x <= 0;
                    num_y <= 0;
                    total_x <= 0;
                    total_y <= 0;
                    state <= SUMMING;
                    com_valid <= 0;
                end
            endcase
        end
    end
    

    
endmodule

`default_nettype wire



