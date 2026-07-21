class_name ProcTextures
extends RefCounted

## Texturas procedurales cacheadas (evitar regenerar por mapa).

static var _cache: Dictionary = {}


static func grid(size: int = 64, cell: int = 16, line: Color = Color(0.35, 0.55, 0.6, 1), fill: Color = Color(0.12, 0.15, 0.18, 1)) -> ImageTexture:
	var key := "g_%d_%d_%s_%s" % [size, cell, line, fill]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for y in size:
		for x in size:
			if x % cell == 0 or y % cell == 0:
				img.set_pixel(x, y, line)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func checker(size: int = 64, tile: int = 8, a: Color = Color(0.2, 0.22, 0.25), b: Color = Color(0.14, 0.15, 0.17)) -> ImageTexture:
	var key := "c_%d_%d_%s_%s" % [size, tile, a, b]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var on := ((x / tile) + (y / tile)) % 2 == 0
			img.set_pixel(x, y, a if on else b)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
