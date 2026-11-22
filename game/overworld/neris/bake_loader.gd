extends RefCounted
## Read-only, all-or-nothing verification for one optional packaged revision.
## No profile/model authority. Cache established only after all 58 files pass.
const ROOT:="res://assets/overworld/neris/bake-v1/"
const INDEX:=ROOT+"index.json"
const INDEX_SHA:="4b8a92ec36dc560418cfa1afc7a55c1e62862ed39d8820f239961653fee81875"
const RECIPE:="06148ad811584eae2f05d1f3f6d656d4ca5fcf8824915ebe5be2a62d8c7c5008"
const BASE_BUFFER_SHA:="0fa7185afdbaa57ed6b5d4557fa1b30d03df7972b399ad4b7456a40b10c8767f"
const EAST_BUFFER_SHA:="c44c0cc5d2b8a2abf9406898502883b8448101d89613d83e260c2f64b740ed7e"
const BASE_COUNT:=56
const PIECES_COUNT:=58
const MAX_PACKAGE_BYTES:=9*1024*1024
const MAX_PART_BYTES:=512*1024
var _verified:Dictionary[String,ArrayMesh]={}
var successful_verifications:=0
var last_check_ms:=0.
var last_reason:=""

func preload_verified(tree:SceneTree,still_valid:Callable,report:Callable)->bool:
	if not _verified.is_empty():
		return still_valid.call()
	last_reason=""
	var start:=Time.get_ticks_usec()
	if not FileAccess.file_exists(INDEX) or FileAccess.get_sha256(INDEX)!=INDEX_SHA:
		return _fail("Missing or invalid bake version manifest.")
	var manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	if not manifest is Dictionary or manifest.get("schema")!=1 or manifest.get("recipe")!=RECIPE or manifest.get("base_buffers")!=BASE_BUFFER_SHA or manifest.get("override_buffers")!=EAST_BUFFER_SHA:
		return _fail("This terrain bake is not the approved source revision.")
	var entries:Variant=manifest.get("pieces")
	if not entries is Array or entries.size()!=PIECES_COUNT:
		return _fail("The shared terrain package is incomplete.")
	var staged:Dictionary[String,ArrayMesh]={}
	var total:=0
	for entry:Variant in entries:
		if not still_valid.call():
			return false
		if not entry is Dictionary:
			return _fail("Invalid tile metadata.")
		var key:=String(entry.get("file",""))
		var coordinate:Variant=entry.get("at")
		var kind:String=entry.get("kind","")
		if not coordinate is Array or coordinate.size()!=2:
			return _fail("Invalid tile coordinate.")
		var x:=int(coordinate[0])
		var z:=int(coordinate[1])
		if x<0 or x>=8 or z<0 or z>=7 or kind not in ["g","b"] or (kind=="b" and Vector2i(x,z) not in [Vector2i(4,3),Vector2i(5,3)]):
			return _fail("Out-of-revision tile coordinate.")
		if key!="%s-%02d-%02d.res"%[kind,x,z] or staged.has(key):
			return _fail("Unexpected or duplicate terrain tile.")
		var bytes:=int(entry.get("bytes",-1))
		if bytes<1 or bytes>=MAX_PART_BYTES or total+bytes>MAX_PACKAGE_BYTES:
			return _fail("Tile exceeds the approved resource budget.")
		total+=bytes
		var resource:=ROOT+key
		if not FileAccess.file_exists(resource) or FileAccess.get_sha256(resource)!=String(entry.get("sha256","")):
			return _fail("A required terrain tile is missing or corrupt.")
		var mesh:=ResourceLoader.load(resource,"ArrayMesh",ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
		var cells_x:=mini(64,502-x*64)
		var cells_z:=mini(64,410-z*64)
		if not mesh or mesh.get_surface_count()!=1 or mesh.surface_get_array_len(0)!=int(entry.get("vertices",0)) or mesh.surface_get_array_index_len(0)!=cells_x*cells_z*6:
			return _fail("A terrain tile could not be safely loaded.")
		staged[key]=mesh
		if staged.size()%8==0:
			report.call(staged.size(),PIECES_COUNT)
			await tree.process_frame
	if not still_valid.call():
		return false
	if staged.size()!=PIECES_COUNT or not staged.has("b-04-03.res") or not staged.has("b-05-03.res"):
		return _fail("Incomplete terrain revision.")
	_verified=staged
	successful_verifications+=1
	last_check_ms=(Time.get_ticks_usec()-start)/1000.
	return true

func chunk_set(boundary:bool)->Array[ArrayMesh]:
	var out:Array[ArrayMesh]=[]
	if _verified.size()!=PIECES_COUNT:
		return out
	for z in 7:
		for x in 8:
			var replacement:=boundary and z==3 and x in [4,5]
			var key:="%s-%02d-%02d.res"%["b" if replacement else "g",x,z]
			if not _verified.has(key):
				out.clear()
				return out
			out.append(_verified[key])
	return out

func _fail(reason:String)->bool:
	last_reason=reason
	return false
