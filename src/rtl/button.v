module button (
    input  wire       clk,         // 100 MHz system clock
    input  wire       rst,         // synchronous reset, active high

    input  wire [2:0] btn,         // raw button inputs (active high), 3 buttons

    output wire [2:0] btn_pressed, // latched on debounced press; held until ack[i]

    input  wire [2:0] ack          // PicoBlaze acknowledge, per-button:
                                   //   ack[i] = 1 clears btn_pressed[i] only
);

    // -----------------------------------------------------------------
    // Debounce window: 10 ms @ 100 MHz. Bump to 2_000_000 for 20 ms.
    // 21-bit counter handles up to ~21 ms.
    // -----------------------------------------------------------------
    localparam integer DEBOUNCE_CYCLES = 1_000_000;
    localparam integer CNT_W           = 21;

    // -----------------------------------------------------------------
    // 2-stage synchronizer for the asynchronous button inputs.
    // Initialised to all-1s to align with the "assume pressed" stance
    // taken by the debouncer (see startup-safety note below). If the
    // button is actually released at boot, the sync flops catch up to
    // 0 within two clocks and the debouncer transitions cleanly with
    // no press edge fired.
    // -----------------------------------------------------------------
    reg [2:0] sync0 = 3'b111;
    reg [2:0] sync1 = 3'b111;
    always @(posedge clk) begin
        sync0 <= btn;
        sync1 <= sync0;
    end

    // -----------------------------------------------------------------
    // Per-button: debounce, detect the rising (press) edge, latch the
    // event, and hold it until the PicoBlaze pulses ack[i]. Each button
    // is fully independent.
    //
    // STARTUP SAFETY
    //   stable_r is initialised to 1 ('pretend pressed') and is forced
    //   back to 1 on rst. This means a button physically held during
    //   FPGA configuration -- or held when rst is asserted -- does NOT
    //   produce a phantom press event when the system comes alive.
    //   The first transition the debouncer can commit is therefore a
    //   release (1 -> 0), which is a falling edge and does not latch.
    //   Only a subsequent real press will set btn_pressed[i].
    //   Held-at-boot  =>  no phantom event.
    // -----------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : g_btn

            reg [CNT_W-1:0] cnt      = {CNT_W{1'b0}};
            reg             stable_r = 1'b1;   // 'pretend pressed' until proven released
            reg             stable_d = 1'b1;
            reg             latched  = 1'b0;

            always @(posedge clk) begin
                if (rst) begin
                    cnt      <= {CNT_W{1'b0}};
                    stable_r <= 1'b1;          // re-arm the same way as power-on
                    stable_d <= 1'b1;
                    latched  <= 1'b0;
                end
                else begin
                    // ---------- Debouncer ----------
                    // Input must persist at a new level for the full
                    // window before being committed; any glitch back
                    // to the prior level resets the counter.
                    stable_d <= stable_r;

                    if (sync1[i] != stable_r) begin
                        if (cnt >= DEBOUNCE_CYCLES - 1) begin
                            stable_r <= sync1[i];
                            cnt      <= {CNT_W{1'b0}};
                        end
                        else begin
                            cnt <= cnt + 1'b1;
                        end
                    end
                    else begin
                        cnt <= {CNT_W{1'b0}};
                    end

                    // ---------- Latch & per-bit ack handshake ----------
                    // ack[i] takes priority over a coincident press edge,
                    // matching the kp_reg / read semantics of keypad.v.
                    if (ack[i])
                        latched <= 1'b0;
                    else if (stable_r & ~stable_d)
                        latched <= 1'b1;
                end
            end

            assign btn_pressed[i] = latched;

        end
    endgenerate

endmodule