module audio_effects (
    input  clk,
    input  sample_end,
    input  sample_req,
    output [15:0] audio_output,
    input  [15:0] audio_input,

    input [15:0] ddr2_audio_output,
    input ddr2_audio_output_valid,

    output reg [15:0] ddr2_audio_input,
    output ddr2_audio_input_valid
);

reg [15:0] dat;

assign audio_output = dat;

always @(posedge clk) begin
    if (sample_end) begin
        ddr2_audio_input <= (ddr2_audio_input_valid) ? audio_input : 16'h0;
    end

    if (sample_req) begin
        dat <= (ddr2_audio_output_valid) ? ddr2_audio_output : 16'h0;
    end
end

endmodule
