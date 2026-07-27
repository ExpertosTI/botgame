class_name WebSafe
extends RefCounted

## Política única anti-OOB WASM en HTML5/móvil.
## Vídeo + SubViewport 3D + GLB masivo + trimesh + partículas GPU han petado
## el heap en Chrome móvil (memory access out of bounds).


static func is_web() -> bool:
	return OS.has_feature("web") or OS.get_name() == "Web"


static func is_lite() -> bool:
	## Misma señal que MapBuilder._lite: menos luces/props/meshes.
	return is_web()


static func kill_video_player(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is VideoStreamPlayer:
		var v := node as VideoStreamPlayer
		v.stop()
		v.stream = null
		v.queue_free()
		return
	for c in node.find_children("*", "VideoStreamPlayer", true, false):
		kill_video_player(c)


static func flat_atmosphere(rect: ColorRect, color: Color = Color(0.03, 0.06, 0.09, 1.0)) -> void:
	if rect == null:
		return
	rect.material = null
	rect.color = color
	rect.modulate = Color.WHITE


## En Web solo el humano local carga GLB; bots/remotos se quedan en cápsula.
static func should_attach_catalog_mesh(peer_id: int) -> bool:
	if not is_web():
		return true
	if NetworkManager.is_bot_peer(peer_id):
		return false
	if NetworkManager.is_solo_practice:
		return peer_id == 1
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return peer_id == 1
	var mp := tree.get_multiplayer()
	if mp != null and mp.has_multiplayer_peer():
		return peer_id == mp.get_unique_id()
	return peer_id == 1


static func strip_gpu_particles(root: Node) -> void:
	if root == null or not is_web():
		return
	for n in root.find_children("*", "GPUParticles3D", true, false):
		(n as GPUParticles3D).emitting = false
		n.queue_free()
