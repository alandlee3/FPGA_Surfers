module crc32_mpeg2(
            input wire clk,
            input wire rst,
            input wire din_valid,
            input wire din,
            output logic [31:0] dout);
 
  always_ff @(posedge clk) begin
    if (rst) begin
        dout <= 32'hFFFF_FFFF;
    end else if (din_valid) begin
        dout[26] <= dout[25] ^ dout[31] ^ din;
        dout[23] <= dout[22] ^ dout[31] ^ din;
        dout[22] <= dout[21] ^ dout[31] ^ din;
        dout[16] <= dout[15] ^ dout[31] ^ din;
        dout[12] <= dout[11] ^ dout[31] ^ din;
        dout[11] <= dout[10] ^ dout[31] ^ din;
        dout[10] <= dout[9] ^ dout[31] ^ din;
        dout[8] <= dout[7] ^ dout[31] ^ din;
        dout[7] <= dout[6] ^ dout[31] ^ din;
        dout[5] <= dout[4] ^ dout[31] ^ din;
        dout[4] <= dout[3] ^ dout[31] ^ din;
        dout[2] <= dout[1] ^ dout[31] ^ din;
        dout[1] <= dout[0] ^ dout[31] ^ din;

        dout[31] <= dout[30];
        dout[30] <= dout[29];
        dout[29] <= dout[28];
        dout[28] <= dout[27];
        dout[27] <= dout[26];
        dout[25] <= dout[24];
        dout[24] <= dout[23];
        dout[21] <= dout[20];
        dout[20] <= dout[19];
        dout[19] <= dout[18];
        dout[18] <= dout[17];
        dout[17] <= dout[16];
        dout[15] <= dout[14];
        dout[14] <= dout[13];
        dout[13] <= dout[12];
        dout[9] <= dout[8];
        dout[6] <= dout[5];
        dout[3] <= dout[2];
        dout[0] <= dout[31] ^ din;
    end
  end
endmodule