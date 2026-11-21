@tool
extends EditorScenePostImport
## Compress the baked material at import for the project's desktop renderer.
## The two masonry materials use the exact same embedded colour atlas.

func _post_import(scene: Node) -> Object:
	var hero := scene.get_node_or_null("HERO_BAKED_MASONRY") as MeshInstance3D
	var tactical := scene.get_node_or_null("TACTICAL_LOD") as MeshInstance3D
	var footing := scene.get_node_or_null("FOOTING_SILT_LOD_ANY") as MeshInstance3D
	if hero == null or tactical == null or footing == null:
		push_error("Cemetery stair import: one or more authored surfaces are missing.")
		return scene
	var detail := hero.mesh.surface_get_material(0) as StandardMaterial3D
	var distant := tactical.mesh.surface_get_material(0) as StandardMaterial3D
	var silt := footing.mesh.surface_get_material(0) as StandardMaterial3D
	if detail == null or distant == null or silt == null:
		push_error("Cemetery stair import: review changes to authored materials.")
		return scene
	var shared_color := _compress(detail.albedo_texture, false)
	var detail_normal := _compress(detail.normal_texture, true)
	var silt_color := _compress(silt.albedo_texture, false)
	if shared_color == null or detail_normal == null or silt_color == null:
		push_error("Cemetery stair import: review missing or changed embedded textures.")
		return scene
	detail.albedo_texture = shared_color
	distant.albedo_texture = shared_color
	detail.normal_texture = detail_normal
	silt.albedo_texture = silt_color
	return scene


func _compress(texture: Texture2D, is_normal: bool) -> PortableCompressedTexture2D:
	if texture == null:
		return null
	var img := texture.get_image()
	if img == null or img.is_empty():
		return null
	if img.is_compressed() and img.decompress() != OK:
		return null
	if not is_normal and img.detect_alpha() == Image.ALPHA_NONE:
		img.convert(Image.FORMAT_RGB8)
	if not img.has_mipmaps() and img.generate_mipmaps(is_normal) != OK:
		return null
	var packed := PortableCompressedTexture2D.new()
	packed.keep_compressed_buffer = true
	packed.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_S3TC, is_normal)
	return packed
