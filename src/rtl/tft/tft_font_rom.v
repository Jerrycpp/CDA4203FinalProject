module tft_font_rom (
    input [7:0] chr_code_i,
    input [3:0] chr_row_i,
    output [7:0] chr_row_o
);  
    // Signals used to output the desired row 8-bit for an 8x16 characters
    wire [11:0] row_addr;
    assign row_addr = {chr_code_i, chr_row_i};

    // IP for Block ROM
    reg [7:0] chr_rom [0:4095];
    initial begin
        $readmemh("chr.hex", chr_rom, 0, 4095);
    end
    assign chr_row_o = chr_rom[row_addr];

endmodule