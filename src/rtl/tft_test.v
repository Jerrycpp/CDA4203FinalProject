module tft_test(
    input CLK,
    input [3:0] BTN,


    output TFT_VDDEN_O,
    output TFT_CLK_O,
    output TFT_DE_O,
    output TFT_DISP_O,
    output TFT_BKLT_O,
    output [7:0] TFT_B_O,
    output [7:0] TFT_G_O,
    output [7:0] TFT_R_O
);

    assign rst = BTN[0];
    // reg [7:0] romdata[0:15];
    reg [3:0] index = 0;
    reg write_en;
    wire [7:0] write_dat;
    // initial begin
    //     romdata[0]  = 8'h48; // 'H' (Decimal 72)
    //     romdata[1]  = 8'h65; // 'e' (Decimal 101)
    //     romdata[2]  = 8'h6C; // 'l' (Decimal 108)
    //     romdata[3]  = 8'h6C; // 'l' (Decimal 108)
    //     romdata[4]  = 8'h6F; // 'o' (Decimal 111)
    //     romdata[5]  = 8'h20; // ' ' (Space, Decimal 32)
    //     romdata[6]  = 8'h77; // 'w' (Decimal 119)
    //     romdata[7]  = 8'h6F; // 'o' (Decimal 111)
    //     romdata[8]  = 8'h72; // 'r' (Decimal 114)
    //     romdata[9]  = 8'h6C; // 'l' (Decimal 108)
    //     romdata[10] = 8'h64; // 'd' (Decimal 100)
    //     romdata[11] = 8'h21; // '!' (Decimal 33)
    // end

    always@(posedge CLK) begin
        if (rst) begin
            index <= 0;
        end
        else begin
            if (index < 12) begin
                index <= index + 1;
            end
        end
    end

    helloworld u0 (
        .a(index),
        .spo(write_dat)
    );
    always@(*) begin
        write_en = (index < 12);
    end


    tft tft (
        .clk            (CLK),
        .rst            (rst),
        .write_en       (write_en),
        .write_dat      (write_dat),
        .set_x_cursor_en(0),
        .set_x_cursor   (0),
        .set_y_cursor_en(0),
        .set_y_cursor   (0),
        .TFT_VDDEN_O    (TFT_VDDEN_O),
        .TFT_CLK_O      (TFT_CLK_O),
        .TFT_DE_O       (TFT_DE_O),
        .TFT_DISP_O     (TFT_DISP_O),
        .TFT_BKLT_O     (TFT_BKLT_O),
        .TFT_B_O        (TFT_B_O),
        .TFT_G_O        (TFT_G_O),
        .TFT_R_O        (TFT_R_O)
    );

    

endmodule