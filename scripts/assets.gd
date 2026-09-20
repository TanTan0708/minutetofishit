class_name Assets
extends RefCounted

## Importer-independent asset loading. Art/audio dropped in while the game
## is being built can exist on disk before Godot's editor has imported it,
## so fall back to reading the file straight off disk when there's no
## imported resource yet.

static func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	var image: Image = Image.load_from_file(path)
	if image != null:
		return ImageTexture.create_from_image(image)
	push_warning("Missing texture: %s" % path)
	return null


## Loads an .mp3 as an AudioStream. Falls back to reading the raw file
## bytes straight into an AudioStreamMP3 if the editor hasn't imported it
## yet (Godot's MP3 codec can decode from raw bytes directly, no import
## step actually required at runtime).
static func load_mp3(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is AudioStream:
			return res
	if FileAccess.file_exists(path):
		var stream := AudioStreamMP3.new()
		stream.data = FileAccess.get_file_as_bytes(path)
		return stream
	push_warning("Missing audio: %s" % path)
	return null
