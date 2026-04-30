module audio_controller(
    //clock and reset
    input clk,          //PicoBlaze & DDR2 clock 100MHz
    input audio_clk,    //audio codec clock 11.8MHz
    input reset,

    //from PicoBlaze
    input record_en,
    input play_en,
    input pause,
    input stop,

    //from audio codec
    input [15:0] audio_in,
    input audio_in_valid,

    //from RAM interface
    input [15:0] data_out,
    input data_out_valid,
    input rdy,

    //to RAM
    output reg write_enable,
    output reg read_request,
    output reg read_ack,
    output reg [25:0] address,
    output reg [15:0] data_in,

    //to audio codec
    output reg [15:0] audio_out,
    output reg audio_out_valid
);

reg [25:0] addr;        //Current address pointer
reg [3:0] state;        //State variable for FSM
reg [3:0] prev_state;   

localparam IDLE   = 0;
localparam RECORD = 1;
localparam PLAY   = 2;
localparam WAIT_READ = 3;
localparam PAUSE  = 4;

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        addr <= 0;
    end else begin
        // DEFAULTS registers
        write_enable <= 0;
        read_request <= 0;
        read_ack <= 0;
        audio_out_valid <= 0;

        case (state)

        IDLE: begin
            if (record_en) state <= RECORD;
            else if (play_en) state <= PLAY;
        end

        RECORD: begin
            if (pause) begin
                prev_state <= RECORD;
                state <= PAUSE;
            end else if (stop) begin
                state <= IDLE;
            end else if (audio_in_valid) begin
                write_enable <= 1;
                data_in <= audio_in;
                address <= addr;
                addr <= addr + 1;
            end
        end

        PLAY: begin
            if (pause) begin
                prev_state <= PLAY;
                state <= PAUSE;
            end else if (stop) begin
                state <= IDLE;
            end else begin
                read_request <= 1;
                state <= WAIT_READ;
            end
        end

        WAIT_READ: begin
            if (pause) begin
                prev_state <= WAIT_READ;
                state <= PAUSE;
            end else if (data_out_valid) begin
                audio_out <= data_out;
                audio_out_valid <= 1;
                read_ack <= 1;
                address <= addr;
                addr <= addr + 1;
                state <= PLAY;
            end
        end

        PAUSE: begin
            if (stop) begin
                state <= IDLE;
            end else if (!pause) begin
                // resume previous state
                state <= prev_state;
            end
        end

        endcase
end


