module tft_controller (
    input clk, // 10 MHz clock
    input rst,

    input pixel,
    output [9:0] tft_hcount,
    output [9:0] tft_vcount,

    output reg TFT_VDDEN_O,
    output TFT_CLK_O,
    output TFT_DE_O,
    output reg TFT_DISP_O,
    output TFT_BKLT_O,
    output [7:0] TFT_B_O,
    output [7:0] TFT_G_O,
    output [7:0] TFT_R_O
);
    // Counter and constant delay amount of cycles
    reg [31:0] counter;
    reg counter_rst;
    localparam POWER_UP_DELAY = 100000 - 1; // 1 ms
    localparam POWER_COOLDOWN = 20000000 - 1; // 200 ms
    localparam BACKLIGHT_WARMUP = 20000000 - 1;
    localparam BACKLIGHT_COOLDOWN = 20000000 - 1;
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

    reg TFT_CLK_EN;
    reg TFT_BKLT_EN;
    always@(*) begin
        TFT_VDDEN_O = 0;
        TFT_CLK_EN = 0;
        TFT_DISP_O = 0;
        TFT_BKLT_EN = 0;
        case (state)
            IDLE : begin
                TFT_VDDEN_O = 1;
            end
            LEDWARMUP : begin
                TFT_VDDEN_O = 1;
                TFT_CLK_EN = 1;
                TFT_DISP_O = 1;
            end
            ON : begin
                TFT_VDDEN_O = 1;
                TFT_CLK_EN = 1;
                TFT_DISP_O = 1;
                TFT_BKLT_EN = 1;
            end
            LEDCOOLDOWN : begin
                TFT_VDDEN_O = 1;
                TFT_CLK_EN = 1;
                TFT_DISP_O = 1;
            end
            PWRCOOLDOWN : begin
                
            end
            default : begin

            end
        endcase
    end

    wire int_bklt;
    pwm pwm_inst (
        .clk  (clk),
        .rst  (rst),
        .pwm_o(int_bklt)
    );
    assign TFT_BKLT_O = (TFT_BKLT_EN) ? int_bklt : 0;

    always@(posedge clk) begin
			if (rst) state <= IDLE;
        else state <= next_state;
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
    (*KEEP="TRUE"*) reg [9:0] vcount = 0;
	 (*KEEP="TRUE"*) reg [9:0] hcount = 0;
    (*KEEP="TRUE"*) reg int_de = 0;
    reg [7:0] int_r = 0, int_g = 0, int_b = 0;
    //
    reg [2:0] clk_counter;
    reg clk_10mhz;
    always@(posedge clk) begin
        if (rst) begin
            clk_counter <= 0;
            clk_10mhz <= 0;
        end
        else if (~TFT_CLK_EN) begin
            clk_counter <= 0;
            clk_10mhz <= 0;
        end
        else begin

            if (clk_counter == 4) begin
                clk_counter <= 0;
                clk_10mhz <= ~clk_10mhz;
            end
            else begin
                clk_counter <= clk_counter + 1;
            end
        end
    end
    assign TFT_CLK_O = clk_10mhz;

    assign TFT_DE_O = (state == IDLE || state == PWRCOOLDOWN) ? 0 : int_de;
    assign TFT_R_O = (TFT_DE_O) ? int_r : 8'h0;
    assign TFT_G_O = (TFT_DE_O) ? int_g : 8'h0;
    assign TFT_B_O = (TFT_DE_O) ? int_b : 8'h0;
    
    assign tft_hcount = hcount;
    assign tft_vcount = vcount;
    always@(posedge clk) begin
        if (rst) begin
            vcount <= VTOTAL - 1;
            hcount <= HTOTAL - 1;
            int_de <= 0;
        end
        else begin
            if (clk_counter == 4 && clk_10mhz == 0) begin
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
                if ((hcount == HTOTAL - 1 && (vcount == VTOTAL - 1 || vcount < VACTIVE - 1)) || (hcount < HACTIVE - 1 && vcount < VACTIVE)) begin
                    int_de <= 1;
                end
                else begin
                    int_de <= 0;
                end
            end
				else begin
					hcount <= hcount;
					vcount <= vcount;
				end
        end
    end

    always@(posedge clk) begin
		if (rst) begin
			int_r <= 0;
			int_g <= 0;
			int_b <= 0;
		end
		else begin
			if (clk_counter == 4 && clk_10mhz == 0) begin
				int_r <= (pixel) ? 8'h0 : 8'hff;
				int_g <= (pixel) ? 8'h0 : 8'hff;
				int_b <= (pixel) ? 8'h0 : 8'hff;
			end
		end
	 end

    
    
endmodule