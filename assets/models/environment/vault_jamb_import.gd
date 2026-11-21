@tool
extends EditorScenePostImport
## Runtime mesh is plain matte stone with one small packed albedo, no new shadow pass.
func _post_import(scene: Node) -> Object:
	var kit := scene.get_node_or_null("VAULT_JAMBS") as MeshInstance3D
	if kit == null:
		push_error("Vault jamb visual missing.")
		return scene
	var mat := kit.mesh.surface_get_material(0) as StandardMaterial3D
	var img := mat.albedo_texture.get_image() if mat.albedo_texture != null else null
	if img == null or img.is_empty() or (img.is_compressed() and img.decompress() != OK):
		push_error("Vault jamb color atlas missing.")
		return scene
	img.convert(Image.FORMAT_RGB8)
	if not img.has_mipmaps() and img.generate_mipmaps() != OK:
		push_error("Vault jamb mip build failed.")
		return scene
	var packed := PortableCompressedTexture2D.new()
	packed.keep_compressed_buffer = true
	packed.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_S3TC)
	mat.albedo_texture = packed
	mat.normal_enabled = false
	mat.normal_texture = null
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return scene
