extends Control
## Licenses: Hardwire (MIT), JetBrains Mono (OFL) and Godot with its third-party components,
## as required when distributing builds. Godot's texts come from the engine itself, so they
## always match the shipped engine. LICENSE and the OFL text are exported via include_filter.

signal exit_requested

const FILES := {
	"Hardwire": "res://LICENSE",
	"JetBrains Mono": "res://fonts/JetBrainsMono-OFL.txt",
}

var text_label: RichTextLabel


func _ready() -> void:
	var column: VBoxContainer = Ui.screen_root(self, get_theme_constant("max_column", "Hardwire"))
	Ui.header(column, "Licenses", exit_requested.emit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = false
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_size_override("normal_font_size", get_theme_font_size("small", "Hardwire"))
	text_label.text = full_text()
	scroll.add_child(text_label)


## All license texts as one document.
static func full_text() -> String:
	var parts: Array[String] = []
	for name: String in FILES:
		parts.append(_section(name, FileAccess.get_file_as_string(FILES[name]).strip_edges()))
	parts.append(_section("Godot Engine", Engine.get_license_text().strip_edges()))
	var components: Array[String] = []
	for info: Dictionary in Engine.get_copyright_info():
		var lines: Array[String] = [str(info.name)]
		for part: Dictionary in info.parts:
			for holder: Variant in part.copyright:
				lines.append("  (c) " + str(holder))
			lines.append("  License: " + str(part.license))
		components.append("\n".join(lines))
	parts.append(_section("Godot third-party components", "\n\n".join(components)))
	var license_info: Dictionary = Engine.get_license_info()
	for license: Variant in license_info:
		parts.append(_section("License: " + str(license), str(license_info[license]).strip_edges()))
	return "\n\n\n".join(parts)


static func _section(name: String, body: String) -> String:
	return "== %s ==\n\n%s" % [name, reflow(body)]


## Joins hard-wrapped lines inside paragraphs so the text wraps to the phone width.
## Blank lines separate paragraphs; paragraphs with indented lines (lists) stay as they are.
static func reflow(text: String) -> String:
	var paragraphs: Array[String] = []
	for paragraph: String in text.replace("\r\n", "\n").split("\n\n"):
		var lines: PackedStringArray = paragraph.split("\n")
		var indented: bool = false
		for line: String in lines:
			indented = indented or line.begins_with(" ") or line.begins_with("\t")
		paragraphs.append(paragraph if indented else " ".join(lines))
	return "\n\n".join(paragraphs)
