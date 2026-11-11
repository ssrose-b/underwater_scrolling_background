/*
 * Camera-controlled underwater background for Tiny Tapeout VGA Playground.
 * Architecture follows the course slides:
 *   VGA (x + camera_x,y + camera_y) -> Map ROM -> BG tile ROM -> RGB222
 * The sea is stationary; the player moves the camera in four directions.
 */
`default_nettype none

module tt_um_vga_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire hsync;
    wire vsync;
    wire display_on;
    wire [9:0] x;
    wire [9:0] y;

    hvsync_generator sync (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(display_on),
        .hpos(x),
        .vpos(y)
    );

    // ui_in[0]=left, ui_in[1]=right, ui_in[2]=up, ui_in[3]=down.
    wire frame_tick = (x == 10'd639 && y == 10'd479);
    reg [9:0] camera_x;
    reg [10:0] camera_y;
    reg [1:0] frame_divider;

    always @(posedge clk) begin
        if (!rst_n) begin
            camera_x <= 10'd320;
            camera_y <= 11'd0;
            frame_divider <= 2'd0;
        end else if (frame_tick) begin
            if (frame_divider == 2'd1) begin
                frame_divider <= 2'd0;
                if (ui_in[1] && !ui_in[0]) begin
                    if (camera_x < 10'd640)
                        camera_x <= camera_x + 2'd2;
                end else if (ui_in[0] && !ui_in[1]) begin
                    if (camera_x >= 2)
                        camera_x <= camera_x - 2'd2;
                    else
                        camera_x <= 10'd0;
                end
                if (ui_in[3] && !ui_in[2]) begin
                    if (camera_y < 11'd480)
                        camera_y <= camera_y + 2'd2;
                end else if (ui_in[2] && !ui_in[3]) begin
                    if (camera_y >= 2)
                        camera_y <= camera_y - 2'd2;
                    else
                        camera_y <= 11'd0;
                end
            end else begin
                frame_divider <= frame_divider + 1'b1;
            end
        end
    end

    // Fixed 1280x960 world (2x2 screens); camera selects a 640x480 viewport.
    wire [10:0] world_x = {1'b0, x} + {1'b0, camera_x};
    wire [10:0] world_y = {1'b0, y} + camera_y;
    wire [6:0] map_x = world_x[10:4];
    wire [6:0] map_y = world_y[10:4];
    wire [3:0] tile_x = world_x[3:0];
    wire [3:0] tile_y = world_y[3:0];

    wire [7:0] tile_index;
    map_rom map (
        .clk(clk),
        .map_x(map_x),
        .map_y(map_y),
        .tile(tile_index)
    );

    // Preserve the pixel-within-tile coordinates while Map ROM is reading.
    reg [3:0] tile_x_d;
    reg [3:0] tile_y_d;
    always @(posedge clk) begin
        tile_x_d <= tile_x;
        tile_y_d <= tile_y;
    end

    wire [5:0] bg_color;
    bg_rom tiles (
        .clk(clk),
        .tile(tile_index),
        .offset_x(tile_x_d),
        .offset_y(tile_y_d),
        .color(bg_color)
    );

    // Match VGA control signals to the two registered ROM stages.
    reg [1:0] hsync_d;
    reg [1:0] vsync_d;
    reg [1:0] display_d;
    always @(posedge clk) begin
        if (!rst_n) begin
            hsync_d <= 2'b11;
            vsync_d <= 2'b11;
            display_d <= 2'b00;
        end else begin
            hsync_d <= {hsync_d[0], hsync};
            vsync_d <= {vsync_d[0], vsync};
            display_d <= {display_d[0], display_on};
        end
    end

    wire [5:0] color = display_d[1] ? bg_color : 6'b000000;
    wire [1:0] red   = color[5:4];
    wire [1:0] green = color[3:2];
    wire [1:0] blue  = color[1:0];

    assign uo_out = {
        hsync_d[1], blue[0], green[0], red[0],
        vsync_d[1], blue[1], green[1], red[1]
    };
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;
    wire _unused_ok = &{ena, ui_in[7:4], uio_in};
endmodule

// Fixed 80x60 tile map: exactly four screens arranged as a 2x2 world.
// This is a synchronous ROM exactly like the Map ROM in the course slides.
module map_rom (
    input  wire       clk,
    input  wire [6:0] map_x,
    input  wire [6:0] map_y,
    output reg  [7:0] tile
);
    (* rom_style = "block" *) reg [7:0] mem [0:4799];
    wire [12:0] address = map_y * 13'd80 + map_x;

    initial begin
        $readmemh("../data/map.mem", mem);
    end

    always @(posedge clk)
        tile <= (map_x < 7'd80 && map_y < 7'd60) ? mem[address] : 8'd0;
endmodule

// One unified 256-tile BG ROM: 256 tiles x 16 x 16 pixels.
// Tile indices 0..59: dithered ocean depth.
// Tile indices 64..123: dithered light-shaft variants.
// Tile 128: Seabed Sand, 129: Kelp Forest, 130: Coral Reef,
// Tile 131: Shipwreck, 132..191: Bubble Trail over each ocean depth.
// Tile indices 192..207: 16 Rocky Seabed wall variants made from four
// quadrants with horizontal, vertical, and 180-degree transformations.
module bg_rom (
    input  wire       clk,
    input  wire [7:0] tile,
    input  wire [3:0] offset_x,
    input  wire [3:0] offset_y,
    output reg  [5:0] color
);
    (* rom_style = "block" *) reg [5:0] mem [0:65535];
    wire [15:0] address = {tile, offset_y, offset_x};

    initial begin
        $readmemh("../data/bg-rom.mem", mem);
    end

    always @(posedge clk)
        color <= mem[address];
endmodule

`default_nettype wire
