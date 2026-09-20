class_name Assets
extends RefCounted

## Importer-independent texture loading. Art generated while the game is being
## built can exist on disk before Godot's editor has imported it, so fall back
## to reading the png straight from disk when there is no imported resource.

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
