class_name DataFile
extends RefCounted
## Reads a data file (data/*.cfg, ConfigFile syntax) for the rules classes. Each of them
## checks what it needs from the sections itself (see `problems` of any `*Rules` class).


## {section: {key: value}} of a file, in the order of the file. A file that can't be read is
## reported with push_error and gives an empty dictionary, which the rules then report as
## missing everything.
static func read_sections(path: String) -> Dictionary:
	var file := ConfigFile.new()
	var error := file.load(path)
	if error != OK:
		push_error("Can't read %s: %s" % [path, error_string(error)])
	var sections := {}
	for section in file.get_sections():
		sections[section] = {}
		for key in file.get_section_keys(section):
			sections[section][key] = file.get_value(section, key)
	return sections
