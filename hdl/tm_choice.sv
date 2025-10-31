module tm_choice (
        input wire [7:0] d, //data byte in
        output logic [8:0] q_m //transition minimized output
    );
    logic [3:0] total_zeros;
    always_comb begin
        total_zeros = d[0] + d[1] + d[2] + d[3] + d[4] + d[5] + d[6] + d[7];
        if (total_zeros > 4 || (total_zeros == 4 && d[0] == 0)) begin
            // option 2
            q_m[0] = d[0];
            for(int i =0; i < 7; i = i+1) begin
                q_m[i+1] = !(d[i+1] ^ q_m[i]);
            end
            q_m[8] = 0;
        end else begin
            // option 1
            q_m[0] = d[0];
            for(int i =0; i < 7; i = i+1) begin
                q_m[i+1] = d[i+1] ^ q_m[i];
            end
            q_m[8] = 1;
        end
    end
endmodule