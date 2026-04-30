module audio_codec_control (
    input audio_clk,
    input audio_codec_clk,
    input rst,

    // Audio codec I/O
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

    // From audio_controller
    input [15:0] audio_out,
    input audio_out_valid,

    // To audio_controller
    output [15:0] audio_in,
    output audio_in_valid
);
    wire [15:0] audio_input, audio_output;
    wire [1:0] sample_end;
    wire [1:0] sample_req;

    audio_codec ac (
        .clk (audio_codec_clk),
        .reset (rst),
        .sample_end (sample_end),
        .sample_req (sample_req),
        .audio_output (audio_output),
        .audio_input (audio_input),
        .channel_sel (2'b10),

        .AUD_ADCLRCK (AUD_ADCLRCK),
        .AUD_ADCDAT (AUD_ADCDAT),
        .AUD_DACLRCK (AUD_DACLRCK),
        .AUD_DACDAT (AUD_DACDAT),
        .AUD_BCLK (AUD_BCLK)
    );

    i2c_av_config av_config (
        .clk (audio_clk),
        .reset (rst),
        .i2c_sclk (AUD_I2C_SCLK),
        .i2c_sdat (AUD_I2C_SDAT),
        .status ()
    );

    // audio_effects ae (
    //     .clk (audio_clk),
    //     .sample_end (sample_end[1]),
    //     .sample_req (sample_req[1]),
    //     .audio_output (audio_output),
    //     .audio_input  (audio_input),
    //     .control (1)
    // );

endmodule