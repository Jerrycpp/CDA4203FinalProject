module tft_char_controller (
    input clk,
    input rst,

    input write_en,
    input [7:0] write_dat,

    

    input set_x_cursor_en,
    input [5:0] set_x_cursor,

    input set_y_cursor_en,
    input [4:0] set_y_cursor,


    // tft_controller_input
    input [9:0] tft_vcount,
    input [9:0] tft_hcount,
    output reg pixel
);
    reg [5:0] x_cursor; // 60
    reg [4:0] y_cursor; // 17
    localparam X_MAX_CHR = 60;
    localparam Y_MAX_LINES = 17;

    // Read
    wire [5:0] rd_col;
    wire [4:0] rd_row;
    wire [3:0] chr_row;
    wire [2:0] chr_col;
    wire [7:0] chr;
    assign rd_col = tft_hcount[8:3];
    assign rd_row = tft_vcount[8:4];
    wire [10:0] rd_addr0;
    wire [10:0] rd_addr;
    assign rd_addr = rd_addr0 + rd_col;
    wire [7:0] rd_dat;
    assign chr_row = tft_vcount[3:0];
    assign chr_col = tft_hcount[2:0];
    mult60 u0 (
	 .clk(clk), // input clk
        .a(rd_row),
        .p(rd_addr0)
    );

    // Write
    wire wr_en;
    assign wr_en = (write_en && (write_dat >= 8'h20 && write_dat <= 8'h7e));
    wire [10:0] wr_addr0;
    wire [10:0] wr_addr;
    assign wr_addr = wr_addr0 + x_cursor;
    mult60 u1 (
	 .clk(clk), // input clk
        .a(y_cursor),
        .p(wr_addr0)
    );

    /*chr_buffer u2 (
        .clk(clk),
        .wr_a(wr_addr),
        .wr_dat(write_dat),
        .wr_en(wr_en),
        .rd_a(rd_addr),
        .rd_dat(rd_dat)
    );*/
	 chr_buffer u2 (
  .a(wr_addr), // input [9 : 0] a
  .d(write_dat), // input [7 : 0] d
  .dpra(rd_addr), // input [9 : 0] dpra
  .clk(clk), // input clk
  .we(wr_en), // input we
  .dpo(rd_dat) // output [7 : 0] dpo
);

    tft_font_rom u3 (
        .chr_code_i(rd_dat),
        .chr_row_i (chr_row),
        .chr_row_o (chr)
    );
    //assign pixel = chr[3'h7 - chr_col];
    wire [2:0] mux_sel;
	 assign mux_sel = 3'h7 - chr_col;
	 always@(*) begin
		pixel = chr[mux_sel];
	 end

    always@(posedge clk) begin
        if (rst) begin
            x_cursor <= 0;
            y_cursor <= 0;
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
                else if (write_dat >= 8'h20 && write_dat <= 8'h7e) begin
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

    

endmodule