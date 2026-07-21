class_name ProcTextures
extends RefCounted

## Texturas procedurales ligeras (sin packs externos pesados).


static func grid(size: int = 128, cell: int = 16, line: Color = Color(0.35, 0.55, 0.6, 1), fill: Color = Color(0.12, 0.15, 0.18, 1)) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for y in size:
		for x in size:
			if x % cell == 0 or y % cell == 0:
				img.set_pixel(x, y, line)
			elif x % cell == 1 or y % cell == 1:
				img.set_pixel(x, y, line.darkened(0.35))
	var tex := ImageTexture.create_from_image(img)
	return tex


static func checker(size: int = 64, tile: int = 8, a: Color = Color(0.2, 0.22, 0.25), b: Color = Color(0.14, 0.15, 0.17)) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var on := ((x / tile) + (y / tile)) % 2 == 0
			img.set_pixel(x, y, a if on else b)
	return ImageTexture.create_from_image(img)


static func stripes(size: int = 64, band: int = 6, a: Color = Color(0.75, 0.2, 0.15), b: Color = Color(0.9, 0.85, 0.2)) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			img.set_pixel(x, y, a if ((x + y) / band) % 2 == 0 else b)
	return ImageTexture.create_from_image(img)


static func noise_tint(size: int = 64, base: Color = Color(0.25, 0.22, 0.2), variance: float = 0.08) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in size:
		for x in size:
			var v := rng.randf_range(-variance, variance)
			img.set_pixel(x, y, Color(clampf(base.r + v, 0, 1), clampf(base.g + v, 0, 1), clampf(base.b + v * 0.5, 0, 1)))
	return ImageTexture.create_from_image(img)
