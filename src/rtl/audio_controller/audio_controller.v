`timescale 1ns / 1ps
module audio_controller(
    //clock and reset
    input clk,          //PicoBlaze & DDR2 clock 100MHz
    // input system_clk,   //System clock for RAM interface 11.8MHz
    input reset,

    //from PicoBlaze
    input [7:0] record_name,        // Recording block number
    input record_name_valid,        // Recording block valid
    input [7:0] play_name,          // Playback block number
    input play_name_valid,          // Playback block valid
    input [7:0] delete_name,        // Block to delete
    input delete_name_valid,        // Delete block valid
    input play_mode,                // Start playback from IDLE
    input play_pause,               // Pause/resume playback
    input recording_mode,           // Start recording from IDLE
    input stop_mode,                // Stop playback and return to IDLE
    input stop_recording,           // Stop recording and return to IDLE
    input delete,                   // Delete single block from IDLE
    input delete_all,               // Delete all blocks from IDLE
    input read_strobe,              // Acknowledge status outputs from PicoBlaze
    
    //from audio codec
    input [15:0] audio_in,
    input audio_in_valid,

    //from RAM interface
    input [15:0] data_out,      // Data read from RAM
    input data_out_valid,       // Data valid signal from RAM
    input rdy,                  // Ready signal from RAM interface (calibration done) 

    //to RAM
    output reg write_enable,
    output reg read_request,
    output reg read_ack,
    output reg [25:0] address,
    output reg [15:0] data_in,

    //to audio codec
    output reg [15:0] audio_out,
    output reg audio_out_valid,

    //to PicoBlaze - Status outputs
    output reg recorded,        // Recording finished (pulses until read_strobe)
    output reg play_finished,   // Playback finished (pulses until read_strobe)
    output reg play_invalid,    // Attempted to play deleted block (pulses until read_strobe)
    output reg deleted          // Deletion finished (pulses until read_strobe)
);


reg [25:0] addr;                    //Current address pointer
reg [25:0] record_end_addr;         //End address of recording (used to detect playback completion)
reg [31:0] block_valid;             //Block validity register (1=valid, 0=deleted) - supports 32 blocks
reg [4:0] state;                    //State variable for FSM
reg [4:0] prev_state;
reg [4:0] record_name_reg;          //Stores the selected recording block number (0-31)
reg [4:0] delete_name_reg;          //Stores the block to delete (0-31)
reg prev_read_strobe;               //Previous read_strobe value for edge detection

// Define DDR2 RAM Interface signals (from wrapper)
wire [25:0] max_ram_address;
wire hw_ram_rasn;
wire hw_ram_casn;
wire hw_ram_wen;
wire [2:0] hw_ram_ba;
wire hw_ram_udqs_p;
wire hw_ram_udqs_n;
wire hw_ram_ldqs_p;
wire hw_ram_ldqs_n;
wire hw_ram_udm;
wire hw_ram_ldm;
wire hw_ram_ck;
wire hw_ram_ckn;
wire hw_ram_cke;
wire hw_ram_odt;
wire [12:0] hw_ram_ad;
wire [15:0] hw_ram_dq;
wire hw_rzq_pin;
wire hw_zio_pin;
wire clkout;
wire rd_data_pres;
wire ledRAM;
wire system_clk;

// Memory block parameters
// DDR2 divided into 32 equal blocks - each block is 2^18 words long

localparam [4:0] IDLE       = 5'd0;
localparam [4:0] RECORD     = 5'd1;
localparam [4:0] PLAY       = 5'd2;
localparam [4:0] WAIT_READ  = 5'd3;
localparam [4:0] PAUSE      = 5'd4;
localparam [4:0] DELETE     = 5'd5;
localparam [4:0] DELETE_ALL = 5'd6;


// Instantiate the RAM interface wrapper
ram_interface_wrapper #(
    .DATA_BYTE_WIDTH(2)
) u_memory_interface (
    .address(address),             // Address to access DDR2
    .data_in(data_in),             // Data to write to DDR2
    .write_enable(write_enable),   // Enable write
    .read_request(read_request),   // Read request
    .read_ack(read_ack),           // Read ack
    .data_out(data_out),           // Data read from DDR2
    .reset(reset),                 // Reset for the DDR2 interface
    .clk(clk),                     // Clock for DDR2 interface
    .hw_ram_rasn(hw_ram_rasn),
    .hw_ram_casn(hw_ram_casn),
    .hw_ram_wen(hw_ram_wen),
    .hw_ram_ba(hw_ram_ba),
    .hw_ram_udqs_p(hw_ram_udqs_p),
    .hw_ram_udqs_n(hw_ram_udqs_n),
    .hw_ram_ldqs_p(hw_ram_ldqs_p),
    .hw_ram_ldqs_n(hw_ram_ldqs_n),
    .hw_ram_udm(hw_ram_udm),
    .hw_ram_ldm(hw_ram_ldm),
    .hw_ram_ck(hw_ram_ck),
    .hw_ram_ckn(hw_ram_ckn),
    .hw_ram_cke(hw_ram_cke),
    .hw_ram_odt(hw_ram_odt),
    .hw_ram_ad(hw_ram_ad),
    .hw_ram_dq(hw_ram_dq),
    .hw_rzq_pin(hw_rzq_pin),
    .hw_zio_pin(hw_zio_pin),
    .clkout(clkout),
    .sys_clk(system_clk),          // System clock
    .rdy(rdy),                     // Ready signal from DDR2 (calibration done)
    .rd_data_pres(rd_data_pres),
    .max_ram_address(max_ram_address),   // Max address for DDR2
    .ledRAM(ledRAM)               // Optional LED indicator for DDR2 activity
);

always @(posedge clk) begin
    if (reset) begin
        state <= IDLE;
        addr <= 0;
        record_end_addr <= 0;
        record_name_reg <= 0;
        delete_name_reg <= 0;
        block_valid <= 32'h00000000;    // No blocks valid until recorded
        prev_read_strobe <= 0;
        write_enable <= 0;
        read_request <= 0;
        read_ack <= 0;
        data_in <= 0;
        audio_out_valid <= 0;
        recorded <= 0;
        play_finished <= 0;
        play_invalid <= 0;
        deleted <= 0;
    end else begin
        // Default values for signals
        write_enable <= 0;
        read_request <= 0;
        read_ack <= 0;
        audio_out_valid <= 0;
        prev_read_strobe <= read_strobe;
        if (|{hw_ram_rasn, hw_ram_casn, hw_ram_wen, hw_ram_ba, hw_ram_udqs_p, hw_ram_udqs_n,
             hw_ram_ldqs_p, hw_ram_ldqs_n, hw_ram_udm, hw_ram_ldm, hw_ram_ck, hw_ram_ckn,
             hw_ram_cke, hw_ram_odt, hw_ram_ad, hw_ram_dq, hw_rzq_pin, hw_zio_pin,
             clkout, rd_data_pres, ledRAM}) begin
            // Silence unused wrapper output analyzer warnings.
        end

        // Reset output flags when read_strobe is acknowledged (edge detection)
        if (read_strobe && !prev_read_strobe) begin
            recorded <= 0;
            play_finished <= 0;
            play_invalid <= 0;
            deleted <= 0;
        end

        // Capture record_name when valid signal is asserted
        if (record_name_valid) begin
            record_name_reg <= record_name[4:0];
        end
        
        // Capture delete_name when valid signal is asserted
        if (delete_name_valid) begin
            delete_name_reg <= delete_name[4:0];
        end

        case (state)

        IDLE: begin
            if (rdy) begin
                if (recording_mode && record_name_valid) begin
                    record_name_reg <= record_name[4:0];
                    addr <= {3'b0, record_name[4:0], 18'h0};  // Start recording at selected block
                    state <= RECORD;
                end else if (play_mode && play_name_valid) begin
                    addr <= {3'b0, play_name[4:0], 18'h0};    // Start playback at selected block
                    if (block_valid[play_name[4:0]]) begin
                        state <= PLAY;
                    end else begin
                        play_invalid <= 1;
                        state <= IDLE;
                    end
                end else if (delete && delete_name_valid) begin
                    delete_name_reg <= delete_name[4:0];
                    state <= DELETE;
                end else if (delete_all) begin
                    state <= DELETE_ALL;
                end
            end
        end

        RECORD: begin
            if (stop_recording) begin
                record_end_addr <= addr;  // Save end address when recording stops
                block_valid[record_name_reg] <= 1;  // Mark recorded block as valid
                recorded <= 1;  // Signal recording finished
                state <= IDLE;
            end else if (addr >= max_ram_address) begin
                addr <= max_ram_address;
            end else if (audio_in_valid) begin
                // Write to DDR2
                write_enable <= 1;      // Enable writing
                data_in <= audio_in;    // Audio input data
                address <= addr;        // Address to store data
                addr <= addr + 1;       // Increment address for next sample
            end
        end

        PLAY: begin
            if (play_pause) begin
                prev_state <= PLAY;
                state <= PAUSE;
            end else if (stop_mode) begin
                state <= IDLE;
            end else begin
                // Read from DDR2
                read_request <= 1;      // Request read from DDR2
                state <= WAIT_READ;
            end
        end

        WAIT_READ: begin
            if (play_pause) begin
                prev_state <= WAIT_READ;
                state <= PAUSE;
            end else if (addr >= record_end_addr) begin
                // Playback complete - all recorded data has been read
                play_finished <= 1;  // Signal playback finished
                state <= IDLE;
            end else if (data_out_valid) begin
                audio_out <= data_out;         // Output audio data from RAM
                audio_out_valid <= 1;          // Mark audio data as valid
                read_ack <= 1;                 // Acknowledge read
                address <= addr;               // Update address for the next read
                addr <= addr + 1;              // Increment the address for the next read
                state <= PLAY;                 // Go back to PLAY state
            end
        end

        DELETE: begin
            // Delete single block
            block_valid[delete_name_reg] <= 0;  // Mark block as deleted
            deleted <= 1;  // Signal deletion finished
            state <= IDLE;
        end

        DELETE_ALL: begin
            // Delete all blocks at once
            block_valid <= 32'h00000000;  // Mark all blocks as deleted
            deleted <= 1;  // Signal deletion finished
            state <= IDLE;
        end

        PAUSE: begin
            if (stop_recording || stop_mode) begin
                if (prev_state == RECORD) begin
                    record_end_addr <= addr;
                    block_valid[record_name_reg] <= 1;
                    recorded <= 1;
                end
                state <= IDLE;
            end else if (!play_pause) begin
                // Resume the previous state
                state <= prev_state;
            end
        end

        default: begin
            state <= IDLE;
        end

        endcase
    end
end

endmodule