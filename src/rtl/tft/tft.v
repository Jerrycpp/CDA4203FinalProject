module tft (
    input clk,
    input rst,

    input write_en,
    input [7:0] write_dat,

    input set_x_cursor_en,
    input [5:0] set_x_cursor,

    input set_y_cursor_en,
    input [4:0] set_y_cursor,

    output TFT_VDDEN_O,
    output TFT_CLK_O,
    output TFT_DE_O,
    output TFT_DISP_O,
    output TFT_BKLT_O,
    output [7:0] TFT_B_O,
    output [7:0] TFT_G_O,
    output [7:0] TFT_R_O
);
    wire pixel;
    wire [9:0] tft_hcount;
    wire [9:0] tft_vcount;

    tft_char_controller tft_char_controller (
        .clk            (clk),
        .rst            (rst),
        .write_en       (write_en),
        .write_dat      (write_dat),
        .set_x_cursor_en(set_x_cursor_en),
        .set_x_cursor   (set_x_cursor),
        .set_y_cursor_en(set_y_cursor_en),
        .set_y_cursor   (set_y_cursor),
        .tft_vcount     (tft_vcount),
        .tft_hcount     (tft_hcount),
        .pixel          (pixel)
    );
    
    tft_controller tft_controller (
        .clk        (clk),
        .rst        (rst),
        .pixel      (pixel),
        .tft_hcount (tft_hcount),
        .tft_vcount (tft_vcount),
        .TFT_VDDEN_O(TFT_VDDEN_O),
        .TFT_CLK_O  (TFT_CLK_O),
        .TFT_DE_O   (TFT_DE_O),
        .TFT_DISP_O (TFT_DISP_O),
        .TFT_BKLT_O (TFT_BKLT_O),
        .TFT_B_O    (TFT_B_O),
        .TFT_G_O    (TFT_G_O),
        .TFT_R_O    (TFT_R_O)
    );


endmodule