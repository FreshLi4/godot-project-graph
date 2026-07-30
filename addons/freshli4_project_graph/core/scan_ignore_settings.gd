@tool
extends RefCounted

const ProjectGraphScanner = preload(
	"res://addons/freshli4_project_graph/core/project_graph_scanner.gd"
)
const SETTINGS_PATH := "user://freshli4_project_graph/settings.cfg"
const SETTINGS_SECTION := "scan"
const SETTINGS_KEY := "ignore_patterns"


static func load_custom_patterns() -> PackedStringArray:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return PackedStringArray()
	var stored_value: Variant = config.get_value(
		SETTINGS_SECTION,
		SETTINGS_KEY,
		PackedStringArray(),
	)
	var patterns := PackedStringArray()
	if stored_value is PackedStringArray:
		patterns = stored_value
	elif stored_value is Array:
		for pattern_value: Variant in stored_value:
			patterns.append(String(pattern_value))
	return ProjectGraphScanner.normalize_ignore_patterns(patterns)


static func save_custom_patterns(patterns: PackedStringArray) -> Error:
	var normalized_patterns := ProjectGraphScanner.normalize_ignore_patterns(patterns)
	var absolute_directory := ProjectSettings.globalize_path(SETTINGS_PATH.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return directory_error

	var config := ConfigFile.new()
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY, normalized_patterns)
	return config.save(SETTINGS_PATH)


static func parse_text(raw_text: String) -> PackedStringArray:
	var patterns := PackedStringArray()
	for raw_line: String in raw_text.split("\n"):
		patterns.append(raw_line)
	return ProjectGraphScanner.normalize_ignore_patterns(patterns)


static func format_text(patterns: PackedStringArray) -> String:
	return "\n".join(ProjectGraphScanner.normalize_ignore_patterns(patterns))


static func format_default_patterns() -> String:
	return "\n".join(ProjectGraphScanner.get_combined_ignore_patterns())
