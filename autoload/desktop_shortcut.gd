extends RefCounted
## Puts a "Skadoosh" shortcut on the Windows desktop.
##
## The released game is one .exe with no installer, so the game makes its own
## shortcut the first time it runs (see Settings). Windows only writes .lnk
## files through its shell, which is reached here with one PowerShell command.

const TITLE := "Skadoosh"
## Command-line switch that asks for the shortcut on any run, for example a
## run from source: godot --path . -- --desktop-shortcut
const FLAG := "--desktop-shortcut"
const ICON_PATH := "user://skadoosh.ico"
const ICON_SIZE := 256
## Every path reaches PowerShell as an environment variable, so no folder name
## can break the quoting. The command itself must stay free of double quotes.
const COMMAND := "$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:SKADOOSH_LINK); " \
		+ "$s.TargetPath = $env:SKADOOSH_TARGET; " \
		+ "if ($env:SKADOOSH_ARGUMENTS) { $s.Arguments = $env:SKADOOSH_ARGUMENTS }; " \
		+ "$s.WorkingDirectory = $env:SKADOOSH_FOLDER; " \
		+ "$s.IconLocation = $env:SKADOOSH_ICON; " \
		+ "$s.Description = 'Skadoosh'; $s.Save()"


static func supported() -> bool:
	return OS.get_name() == "Windows" and DisplayServer.get_name() != "headless"


## Where the shortcut lives ("" when this machine has no desktop folder).
static func link_path() -> String:
	var desktop := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	return "" if desktop.is_empty() else desktop.path_join(TITLE + ".lnk")


static func exists() -> bool:
	var link := link_path()
	return not link.is_empty() and FileAccess.file_exists(link)


## Whether a released build should write the shortcut on this launch.
## A first launch makes one unless the desktop already has a shortcut of that
## name. Later launches only repoint a shortcut the game made itself
## (`owned_target` is the file it starts) once the game runs from another
## file, and never bring back one the player deleted.
static func is_due(offered: bool, owned_target: String, program: String, present: bool) -> bool:
	if not offered:
		return not present
	return present and not owned_target.is_empty() and owned_target != program


## Writes the shortcut for the way the game is running now. Returns false when
## the request could not be handed to Windows.
static func make() -> bool:
	var link := link_path()
	if not supported() or link.is_empty():
		return false
	var program := OS.get_executable_path()
	var folder := program.get_base_dir()
	var arguments := ""
	if not OS.has_feature("template"):
		# Running from source: the program is Godot itself and needs the project.
		folder = ProjectSettings.globalize_path("res://").trim_suffix("/")
		arguments = "--path \"%s\"" % _native(folder)
	var icon := _write_icon()
	if icon.is_empty():
		icon = program
	OS.set_environment("SKADOOSH_LINK", _native(link))
	OS.set_environment("SKADOOSH_TARGET", _native(program))
	OS.set_environment("SKADOOSH_ARGUMENTS", arguments)
	OS.set_environment("SKADOOSH_FOLDER", _native(folder))
	OS.set_environment("SKADOOSH_ICON", _native(icon) + ",0")
	return OS.create_process("powershell.exe",
			["-NoProfile", "-NonInteractive", "-Command", COMMAND]) > 0


## The game icon as the bytes of a Windows .ico file: one 256 px PNG image
## behind the small ICO header, which Windows scales down for smaller sizes.
static func icon_bytes(source: Image) -> PackedByteArray:
	var image := source.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var png := image.save_png_to_buffer()
	var bytes := PackedByteArray()
	bytes.resize(22)
	bytes.fill(0)
	bytes.encode_u16(2, 1)  # File type: icon.
	bytes.encode_u16(4, 1)  # Number of images.
	# Bytes 6 and 7 are the width and height, where 0 stands for 256.
	bytes.encode_u16(10, 1)  # Colour planes.
	bytes.encode_u16(12, 32)  # Bits per pixel.
	bytes.encode_u32(14, png.size())
	bytes.encode_u32(18, bytes.size())  # Where the image starts.
	bytes.append_array(png)
	return bytes


## Saves the icon beside the settings and returns its full path, or "" on failure.
static func _write_icon() -> String:
	var texture := load("res://icon.png") as Texture2D
	if texture == null:
		return ""
	var image := texture.get_image()
	if image == null or image.is_empty():
		return ""
	var file := FileAccess.open(ICON_PATH, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(icon_bytes(image))
	file.close()
	return ProjectSettings.globalize_path(ICON_PATH)


## Windows shortcuts want backslashes; Godot hands out forward slashes.
static func _native(path: String) -> String:
	return path.replace("/", "\\")
