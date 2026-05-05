module top (
    input clk,
    input rst,

    // TFT
    output TFT_VDDEN_O,
    output TFT_CLK_O,
    output TFT_DE_O,
    output TFT_DISP_O,
    output TFT_BKLT_O,
    output [7:0] TFT_B_O,
    output [7:0] TFT_G_O,
    output [7:0] TFT_R_O,

    // Keypad
    input [3:0] KYPD_COL,
    input [3:0] KYPD_ROW,

    // Audio codec
    inout  AUD_ADCLRCK,
    input  AUD_ADCDAT,

    inout  AUD_DACLRCK,
    output AUD_DACDAT,

    output AUD_XCK,
    inout  AUD_BCLK,

    output AUD_I2C_SCLK,
    inout  AUD_I2C_SDAT,

    output AUD_MUTE,
	output PLL_LOCKED,

    // Switches
    input [7:0] SW,
    input [3:0] BTN
);
    wire write_en;
    wire [7:0] write_dat;
    wire set_x_cursor_en;
    wire [5:0] set_x_cursor;
    wire set_y_cursor_en;
    wire [4:0] set_y_cursor;
    tft tft (
        .clk            (clk),
        .rst            (rst),
        .write_en       (write_en),
        .write_dat      (write_dat),
        .set_x_cursor_en(set_x_cursor_en),
        .set_x_cursor   (set_x_cursor),
        .set_y_cursor_en(set_y_cursor_en),
        .set_y_cursor   (set_y_cursor),
        .TFT_VDDEN_O    (TFT_VDDEN_O),
        .TFT_CLK_O      (TFT_CLK_O),
        .TFT_DE_O       (TFT_DE_O),
        .TFT_DISP_O     (TFT_DISP_O),
        .TFT_BKLT_O     (TFT_BKLT_O),
        .TFT_B_O        (TFT_B_O),
        .TFT_G_O        (TFT_G_O),
        .TFT_R_O        (TFT_R_O)
    );
    audio_controller audio_controller (
        .clk              (clk),
        .system_clk       (system_clk),
        .reset            (reset),
        .record_name      (record_name),
        .record_name_valid(record_name_valid),
        .play_name        (play_name),
        .play_name_valid  (play_name_valid),
        .delete_name      (delete_name),
        .delete_name_valid(delete_name_valid),
        .play_mode        (play_mode),
        .play_pause       (play_pause),
        .recording_mode   (recording_mode),
        .stop_mode        (stop_mode),
        .stop_recording   (stop_recording),
        .delete           (delete),
        .delete_all       (delete_all),
        .read_strobe      (read_strobe),
        .audio_in         (audio_in),
        .audio_in_valid   (audio_in_valid),
        .data_out         (data_out),
        .data_out_valid   (data_out_valid),
        .rdy              (rdy),
        .write_enable     (write_enable),
        .read_request     (read_request),
        .read_ack         (read_ack),
        .address          (address),
        .data_in          (data_in),
        .audio_out        (audio_out),
        .audio_out_valid  (audio_out_valid),
        .recorded         (recorded),
        .play_finished    (play_finished),
        .play_invalid     (play_invalid),
        .deleted          (deleted)
    );

    



endmodule