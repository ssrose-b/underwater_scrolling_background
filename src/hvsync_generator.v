`default_nettype none

// 640x480 @ 60 Hz timing for the VGA Playground 25.175 MHz clock.
module hvsync_generator (
    input  wire       clk,
    input  wire       reset,
    output wire       hsync,
    output wire       vsync,
    output wire       display_on,
    output reg  [9:0] hpos,
    output reg  [9:0] vpos
);
    always @(posedge clk) begin
        if (reset) begin
            hpos <= 10'd0;
            vpos <= 10'd0;
        end else if (hpos == 10'd799) begin
            hpos <= 10'd0;
            if (vpos == 10'd524)
                vpos <= 10'd0;
            else
                vpos <= vpos + 1'b1;
        end else begin
            hpos <= hpos + 1'b1;
        end
    end

    assign hsync = !(hpos >= 10'd656 && hpos < 10'd752);
    assign vsync = !(vpos >= 10'd490 && vpos < 10'd492);
    assign display_on = (hpos < 10'd640 && vpos < 10'd480);
endmodule

`default_nettype wire
