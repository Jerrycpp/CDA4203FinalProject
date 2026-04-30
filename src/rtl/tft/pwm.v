module pwm (
    input clk, // For 10 MHz clock, I want the BKLT to be half
    input rst,

    output pwm_o
);
    reg [31:0] counter;
    localparam MAX_COUNTER = 4000;
    localparam CLOCK_DIVIDER = 2000;

    always@(posedge clk) begin
        if (rst) begin
            counter <= 0;
        end
        else begin
            if (counter == MAX_COUNTER - 1) begin
                counter <= 0;
            end
            else begin
                counter <= counter + 1;
            end
        end
    end

    assign pwm_o = (counter < CLOCK_DIVIDER) ? 1 : 0;
endmodule