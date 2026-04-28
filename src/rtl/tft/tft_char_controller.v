module tft_char_controller (
    input clk,
    input rst,

    input write_en,
    input [7:0] write_dat,

    input clear,

    input set_x_cursor_en,
    input [5:0] set_x_cursor,

    input set_y_cursor_en,
    input [4:0] set_y_cursor,


    // tft_controller_input
    input [17:0] pixel,
    output pixel_true
);
    reg [5:0] x_cursor;
    reg [4:0] y_cursor;
    localparam X_MAX_CHR = 60;
    localparam Y_MAX_LINES = 17;

    reg [7:0] chr_buffer [16:0][59:0];
    integer i, j;

    

    always@(posedge clk) begin
        if (rst) begin
            x_cursor <= 0;
            y_cursor <= 0;
            for (i = 0; i < 17; i = i + 1) begin
                for (j = 0; j < 60; j = j + 1) begin
                    chr_buffer[i][j] <= 0;
                end
            end
        end
        else if (clear) begin
            x_cursor <= 0;
            y_cursor <= 0;
            for (i = 0; i < 17; i = i + 1) begin
                for (j = 0; j < 60; j = j + 1) begin
                    chr_buffer[i][j] <= 0;
                end
            end
        end
        else begin
            if (write_en) begin
                if (write_dat == 8'hA) begin
                    x_cursor <= 0;
                    if (y_cursor == Y_MAX_LINES - 1) begin
                        y_cursor <= 0;
                    end
                    else begin
                        y_cursor <= y_cursor + 1;
                    end
                end
                else if (write_dat == 8'h9) begin
                    if (x_cursor < X_MAX_CHR - 2) begin
                        x_cursor <= x_cursor + 2;
                    end
                end
                else if (write_dat >= 8'h20 && write_dat <= 8'h7e) begin
                    chr_buffer[y_cursor][x_cursor] <= write_dat;
                    if (x_cursor == X_MAX_CHR - 1) begin
                        if (y_cursor == Y_MAX_LINES - 1) begin
                            x_cursor <= 0;
                            y_cursor <= 0;
                        end
                        else begin
                            x_cursor <= 0;
                            y_cursor <= y_cursor + 1;
                        end
                    end
                    else begin
                        x_cursor <= x_cursor + 1;
                    end
                end
            end
            else if (set_x_cursor_en) begin
                x_cursor <= set_x_cursor;
            end
            else if (set_y_cursor_en) begin
                y_cursor <= set_y_cursor;
            end
        end
    end

    wire [4:0] chr_row;
    wire [5:0] chr_col;
    wire [3:0] row_in_chr;
    wire [2:0] col_in_chr;
    wire [7:0] chr_row_o;

    
    assign chr_row = (pixel[17:9] >> 4);
    assign chr_col = (pixel[8:0] >> 3);
    assign row_in_chr = pixel[12:9];
    assign col_in_chr = pixel[2:0];
    

    tft_font_rom u0 (chr_buffer[chr_row][chr_col], row_in_chr, chr_row_o);
    assign pixel_true = chr_row_o[col_in_chr];

endmodule