# underwater vga tile background

camera-controlled underwater tile-map background written in verilog for tiny tapeout vga playground.

## controls

* `ui_in[0]` - camera left
* `ui_in[1]` - camera right
* `ui_in[2]` - camera up
* `ui_in[3]` - camera down

## features

* 640x480 RGB222 VGA output
* 1280x960 world (80x60 tiles)
* 16x16 tiles
* synchronous map ROM and unified 256-tile background ROM
* two-clock Map ROM -> BG ROM pipeline
* CC0 underwater sand, kelp, coral, and bubble assets

## vga playground

```text
https://vga-playground.com/?repo=https://github.com/ssrose-b/underwater-vga-background
```

## assets

Assets are from the [Underwater Reef Pack](https://freegamesprites.com/en/packs/underwater), licensed CC0.

