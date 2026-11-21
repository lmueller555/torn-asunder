@tool
extends EditorScenePostImport
## Local audit candidate, scoped to the Record Room's shared bake.
func _post_import(scene: Node) -> Object:
	var hero := scene.get_node_or_null("RECORD_ROOM_HERO") as MeshInstance3D
	var low := scene.get_node_or_null("RECORD_ROOM_TACTICAL") as MeshInstance3D
	if hero == null or low == null:
		push_error("Record Room surfaces missing.")
		return scene
	var hi := hero.mesh.surface_get_material(0) as StandardMaterial3D
	var far := low.mesh.surface_get_material(0) as StandardMaterial3D
	var color := _pack(hi.albedo_texture, false)
	var normal := _pack(hi.normal_texture, true)
	if color == null or normal == null:
		push_error("Record Room textures missing.")
		return scene
	hi.albedo_texture = color
	far.albedo_texture = color
	hi.normal_texture = normal
	return scene


func _pack(tex: Texture2D, is_normal: bool) -> PortableCompressedTexture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed() and img.decompress() != OK:
		return null
	img.convert(Image.FORMAT_RGB8)
	if not img.has_mipmaps() and img.generate_mipmaps(is_normal) != OK:
		return null
	var packed := PortableCompressedTexture2D.new()
	packed.keep_compressed_buffer = true
	packed.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_S3TC, is_normal)
	return packed
