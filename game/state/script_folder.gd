class_name ScriptFolder
extends RefCounted
## The scripts of a folder, for the registries that take one script per topic or command.


## The paths of the scripts in `directory`, by name. `ResourceLoader` lists the resources, so this
## works in an exported game too (the editor's directory listing does not); folders and any files
## that are no scripts are left out.
static func paths(directory: String) -> Array[String]:
	var found: Array[String] = []
	for file in ResourceLoader.list_directory(directory):
		if file.ends_with(".gd"):
			found.append(directory.path_join(file))
	found.sort()
	return found
