module tft_controller (
    input clk, // 10 MHz clock
    input rst,

    input pixel_true,
    output [17:0] pixel,

    output reg TFT_VDDEN_O,
    output reg TFT_CLK_O,
    output TFT_DE_O,
    output reg TFT_DISP_O,
    output reg TFT_BKLT_O,
    output [7:0] TFT_B_O,
    output [7:0] TFT_G_O,
    output [7:0] TFT_R_O
);
    // Counter and constant delay amount of cycles
    reg [22:0] counter;
    reg counter_rst;
    localparam POWER_UP_DELAY = 10000 - 1; // 1 ms
    localparam POWER_COOLDOWN = 2000000 - 1; // 200 ms
    localparam BACKLIGHT_WARMUP = 2000000 - 1;
    localparam BACKLIGHT_COOLDOWN = 2000000 - 1;
    //





    // State encoding
    localparam IDLE = 0, LEDWARMUP = 1, ON = 2, LEDCOOLDOWN = 3, PWRCOOLDOWN = 4;
    //
    reg [2:0] state, next_state;
    always@(*) begin
        next_state = state;
        counter_rst = 0;
        case (state)
            IDLE : begin
                if (counter == POWER_UP_DELAY) begin
                    next_state = LEDWARMUP;
                    counter_rst = 1;
                end
            end
            LEDWARMUP : begin
                if (counter == BACKLIGHT_WARMUP) begin
                    next_state = ON;
                    counter_rst = 1;
                end
                if (rst) begin
                    next_state = LEDCOOLDOWN;
                end
            end
            ON : begin
                if (rst) begin
                    next_state = LEDCOOLDOWN;
                end
            end
            LEDCOOLDOWN : begin
                if (counter == BACKLIGHT_COOLDOWN) begin
                    next_state = PWRCOOLDOWN;
                    counter_rst = 1;
                end
            end
            PWRCOOLDOWN : begin
                if (counter == POWER_COOLDOWN) begin
                    next_state = IDLE;
                    counter_rst = 1;
                end
            end
            default : begin

            end
        endcase
    end

    always@(*) begin
        TFT_VDDEN_O = 0;
        TFT_CLK_O = 0;
        TFT_DISP_O = 0;
        TFT_BKLT_O = 0;
        case (state)
            IDLE : begin
                TFT_VDDEN_O = 1;
            end
            LEDWARMUP : begin
                TFT_VDDEN_O = 1;
                TFT_CLK_O = clk;
                TFT_DISP_O = 1;
            end
            ON : begin
                TFT_VDDEN_O = 1;
                TFT_CLK_O = clk;
                TFT_DISP_O = 1;
                TFT_BKLT_O = 1;
            end
            LEDCOOLDOWN : begin
                TFT_VDDEN_O = 1;
                TFT_CLK_O = clk;
                TFT_DISP_O = 1;
            end
            PWRCOOLDOWN : begin
                
            end
            default : begin

            end
        endcase
    end

    always@(posedge clk) begin
        state <= next_state;
    end

    always@(posedge clk) begin
        if (counter_rst) begin
            counter <= 0;
        end
        else begin
            counter <= counter + 1;
        end
    end

    // Display-related registers and parameters
    localparam HACTIVE = 480, VACTIVE = 272, HTOTAL = 525, VTOTAL = 288;
    reg [9:0] vcount, hcount;
    reg int_de;
    reg [7:0] int_r, int_g, int_b;
    //
    

    assign TFT_DE_O = (state == IDLE || state == PWRCOOLDOWN) ? 0 : int_de;
    assign TFT_R_O = (state == IDLE || state == PWRCOOLDOWN) ? 8'hFF : int_r;
    assign TFT_G_O = (state == IDLE || state == PWRCOOLDOWN) ? 8'hFF : int_g;
    assign TFT_B_O = (state == IDLE || state == PWRCOOLDOWN) ? 8'hFF : int_b;
    assign pixel = (hcount < HACTIVE && vcount < VACTIVE) ? {vcount[8:0], hcount[8:0]} : 0;  

    always@(posedge clk) begin
        if (rst) begin
            vcount <= 0;
            hcount <= 0;
        end
        else begin
            if (hcount == HTOTAL - 1) begin
                if (vcount == VTOTAL - 1) begin
                    vcount <= 0;
                    hcount <= 0;
                end
                else begin
                    hcount <= 0;
                    vcount <= vcount + 1;
                end
            end
            else begin
                hcount <= hcount + 1;
            end
        end
    end

    always@(*) begin
        int_de = 0;
        int_r = 0;
        int_g = 0;
        int_b = 0;
        if (hcount < HACTIVE && vcount < VACTIVE) begin
            int_de = 1;
            int_r = (pixel_true) ? 8'h0 : 8'hFF;
            int_g = (pixel_true) ? 8'h0 : 8'hFF;
            int_b = (pixel_true) ? 8'h0 : 8'hFF;
        end
    end
    
endmodule