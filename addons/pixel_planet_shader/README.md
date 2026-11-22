# Pixel Planet - Godot Shader

A spinning pixel art planet drawn by a CanvasItem shader, with no textures. Six kinds of planet, lit in flat shade steps.

- Godot 4.x, GL Compatibility, Mobile and Forward+. Put it on a square `ColorRect`.
- Try it in your browser, with sliders and live code editing, before you download: see the itch.io page.

## Use it in your project

1. Copy `shaders/pixel_planet.gdshader` into your project.
2. Add a square `ColorRect`, create a `ShaderMaterial` on it and assign the shader.
3. Pick `planet_type` and tweak the parameters in the Inspector.

## Planet types

Terran (oceans, land, clouds), Desert, Ice, Lava (the rivers glow in the dark), Gas giant (bands, optional rings) and Moon (craters, no air).

## Parameters

| Name | What it does |
|---|---|
| `planet_type` | Terran (oceans, land, clouds), Desert, Ice, Lava (glowing rivers), Gas giant (bands) or Moon (craters, no atmosphere) |
| `pixels` | How many big pixels wide the planet is. 64 by default; lower is chunkier, higher has more detail. Use 96 or more with rings |
| `seed` | Any number gives a different world; the same seed gives the same planet |
| `spin` | Rotation speed in turns per second (negative spins the other way, 0 stops it) |
| `scale` | Size of the features: continents, gas bands, craters (higher = more and smaller) |
| `sea_level` | How much of the surface is low ground: water on Terran, canyons on Desert, glowing rivers on Lava |
| `light_dir` | Where the light comes from (x right, y up, z toward you) |
| `shade_steps` | How many flat steps the light is cut into, 2 (hard) to 6 (smooth) |
| `tilt` | How far the north pole leans toward the camera; needed to see the polar caps |
| `ice_caps` | Size of the polar caps on Terran, Desert and Ice (0 removes them) |
| `cloud_cover` | How much of the sky is cloudy on Terran, Desert and Ice; clouds cast shadows (0 = clear) |
| `atmosphere_strength` | Brightness of the glow around the edge; its color depends on the type (0 = off) |
| `rings` | Turns the rings on; the planet shrinks to leave room |
| `ring_open` | How open the rings look: 1 from above, close to 0 edge-on |
| `ring_angle` | Rotates the rings on the screen |

Note: the node's `modulate` is not applied; the shader outputs the final color. Clouds turn exactly twice as fast as the ground, so one full turn of the planet loops cleanly (good for GIFs).

## Example project

Open this folder in Godot 4.x and run it: `demo.tscn` goes through the six planet types. `main.tscn` has a single Terran planet.

## License

CC0 (public domain): see `LICENSE.txt`. Credit is appreciated, not required.

This exists because of Deep-Fold's Pixel Planet Generator (MIT, https://deep-fold.itch.io/pixel-planet-generator): beautiful, free, and the reason I wanted to try this. If you like pixel planets, go download it too.


## Asset Store install

Installed at `res://addons/pixel_planet_shader/` (no plugin to enable: only the shader, an example scene in `example/` and this README).
