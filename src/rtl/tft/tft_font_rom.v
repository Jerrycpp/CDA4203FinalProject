module tft_font_rom (
    input [7:0] chr_code_i,
    input [3:0] chr_row_i,
    output [7:0] chr_row_o
);  
    // Signals used to output the desired row 8-bit for an 8x16 characters
    wire [11:0] row_addr;
    assign row_addr = {chr_code_i, chr_row_i};
    


    chr_rom u0 (
        .a(row_addr),
        .spo(chr_row_o)
    );
    

endmodule