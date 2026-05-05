module keypad (
    input  wire        clk,        // 100 MHz system clock
    input  wire        rst,        // synchronous reset, active high

    output reg  [3:0]  col,        // active-low column drive (one-cold), to keypad
    input  wire [3:0]  row,        // active-low row read, from keypad

    output wire [7:0]  kp,         // captured {col, row} for the PicoBlaze to decode
    output wire        kp_valid,   // high while kp holds a debounced press

    input  wire        read        // PicoBlaze strobe: clears kp_reg on assert
);

    // -----------------------------------------------------------------
    // Timing parameters (100 MHz clock => 10 ns period)
    //   SCAN_PHASE_CYCLES : time to hold each column low while searching
    //                       100_000   ->  1 ms per phase, 4 ms full sweep
    //   DEBOUNCE_CYCLES   : key must remain pressed this long to qualify
    //                       1_000_000 -> 10 ms (use 2_000_000 for 20 ms)
    // -----------------------------------------------------------------
    localparam integer SCAN_PHASE_CYCLES = 100_000;
    localparam integer DEBOUNCE_CYCLES   = 1_000_000;

    // -----------------------------------------------------------------
    // 2-stage synchronizer for the asynchronous row inputs.
    // On a pull-up matrix, idle reads as 4'hF; a press pulls one bit low.
    // -----------------------------------------------------------------
    reg [3:0] row_sync0 = 4'hF;
    reg [3:0] row_sync1 = 4'hF;
    always @(posedge clk) begin
        row_sync0 <= row;
        row_sync1 <= row_sync0;
    end
    wire [3:0] row_s       = row_sync1;
    wire       row_pressed = (row_s != 4'hF);

    // -----------------------------------------------------------------
    // FSM
    //   S_INIT          - startup safety: scan all 4 columns and only
    //                     leave once a full sweep observes no press in
    //                     any column. Prevents a key held during FPGA
    //                     configuration (or while rst is asserted) from
    //                     producing a phantom captured event.
    //   S_SCAN          - rotate col through the 4 one-cold patterns
    //   S_DEBOUNCE      - col frozen on the hit column, time the press
    //   S_VALID         - kp_reg loaded, kp_valid high, wait for read
    //   S_WAIT_RELEASE  - don't accept another press until user lets go
    // -----------------------------------------------------------------
    localparam [2:0] S_INIT         = 3'd0,
                     S_SCAN         = 3'd1,
                     S_DEBOUNCE     = 3'd2,
                     S_VALID        = 3'd3,
                     S_WAIT_RELEASE = 3'd4;

    reg  [2:0]  state        = S_INIT;
    reg  [19:0] cnt          = 20'd0;   // shared timer for scan and debounce
    reg  [1:0]  col_phase    = 2'd0;    // 0..3, selects which column is driven low
    reg  [7:0]  kp_reg       = 8'h00;
    reg         kp_valid_reg = 1'b0;
    reg         sweep_clean  = 1'b1;    // S_INIT: 1 if no press seen so far this sweep

    assign kp       = kp_reg;
    assign kp_valid = kp_valid_reg;

    // One-cold pattern for a given scan phase.
    function [3:0] col_pattern;
        input [1:0] phase;
        begin
            case (phase)
                2'd0: col_pattern = 4'b1110;
                2'd1: col_pattern = 4'b1101;
                2'd2: col_pattern = 4'b1011;
                2'd3: col_pattern = 4'b0111;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state        <= S_INIT;
            cnt          <= 20'd0;
            col_phase    <= 2'd0;
            col          <= 4'b1110;
            kp_reg       <= 8'h00;
            kp_valid_reg <= 1'b0;
            sweep_clean  <= 1'b1;
        end
        else begin
            case (state)

                // -------------------------------------------------
                // S_INIT (startup safety)
                // Cycle col through all 4 patterns exactly like
                // S_SCAN, but never debounce or capture. sweep_clean
                // accumulates whether any row press was observed
                // during the current 4-phase sweep. Only when an
                // entire sweep stays clean do we transition to S_SCAN.
                // A held-at-boot key keeps us here until release.
                // -------------------------------------------------
                S_INIT: begin
                    if (cnt >= SCAN_PHASE_CYCLES - 1) begin
                        cnt       <= 20'd0;
                        col_phase <= col_phase + 2'd1;
                        col       <= col_pattern(col_phase + 2'd1);

                        if (col_phase == 2'd3) begin
                            // End of a full 4-phase sweep. Decision uses
                            // both the accumulated flag and the current
                            // cycle's reading.
                            if (sweep_clean && !row_pressed) begin
                                state <= S_SCAN;
                            end
                            sweep_clean <= 1'b1;   // arm fresh accumulator
                        end
                    end
                    else begin
                        cnt <= cnt + 20'd1;
                        if (row_pressed) sweep_clean <= 1'b0;
                    end
                end

                // -------------------------------------------------
                // Cycle the column drive. The instant a row reads
                // non-idle during the current phase, lock on -- col
                // is simply left at its current pattern.
                // -------------------------------------------------
                S_SCAN: begin
                    if (row_pressed) begin
                        state <= S_DEBOUNCE;
                        cnt   <= 20'd0;
                    end
                    else if (cnt >= SCAN_PHASE_CYCLES - 1) begin
                        cnt       <= 20'd0;
                        col_phase <= col_phase + 2'd1;
                        col       <= col_pattern(col_phase + 2'd1);
                    end
                    else begin
                        cnt <= cnt + 20'd1;
                    end
                end

                // -------------------------------------------------
                // col is held at the hit column. Require the row to
                // stay pressed for the entire debounce window; an
                // early release is treated as a bounce.
                // -------------------------------------------------
                S_DEBOUNCE: begin
                    if (!row_pressed) begin
                        state <= S_SCAN;
                        cnt   <= 20'd0;
                    end
                    else if (cnt >= DEBOUNCE_CYCLES - 1) begin
                        // Capture the raw pin state at this rising edge.
                        // PicoBlaze PSM does the {col,row} -> key-name decode.
                        kp_reg       <= {col, row_s};
                        kp_valid_reg <= 1'b1;
                        state        <= S_VALID;
                    end
                    else begin
                        cnt <= cnt + 20'd1;
                    end
                end

                // -------------------------------------------------
                // Hold the captured value until the PicoBlaze
                // acknowledges by asserting read.
                // -------------------------------------------------
                S_VALID: begin
                    if (read) begin
                        kp_reg       <= 8'h00;
                        kp_valid_reg <= 1'b0;
                        state        <= S_WAIT_RELEASE;
                    end
                end

                // -------------------------------------------------
                // Refuse to register another press until this one is
                // physically released (row returns to 4'hF on the
                // locked column). Used for the post-read path only --
                // S_INIT covers the startup case, which has the
                // additional complication of a key possibly being
                // held in a different column than the one we last had
                // driven low.
                // -------------------------------------------------
                S_WAIT_RELEASE: begin
                    if (!row_pressed) begin
                        state <= S_SCAN;
                        cnt   <= 20'd0;
                    end
                end

                default: state <= S_INIT;
            endcase
        end
    end

endmodule