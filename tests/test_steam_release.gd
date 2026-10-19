extends "res://tests/hardwire_test.gd"
## M10 Steam release: name, save folder and Windows exe metadata (SPEC: Steam release, D-033).


func test_desktop_saves_live_in_a_hardwire_folder() -> void:
	# Not Godot's default <data>/godot/app_userdata/Hardwire: Steam Auto-Cloud is set to this path.
	assert_eq(OS.get_user_data_dir(), OS.get_data_dir().path_join("Hardwire"))


func test_windows_exe_carries_icon_name_version_and_company() -> void:
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK)
	var options: String = ""
	for section: String in presets.get_sections():
		if presets.get_value(section, "platform", "") == "Windows Desktop":
			options = section + ".options"
	assert_ne(options, "", "a Windows preset exists")
	assert_ne(ProjectSettings.get_setting("application/config/version", ""), "")
	# Empty version fields make Godot stamp the exe with application/config/version.
	assert_eq(presets.get_value(options, "application/file_version", ""), "")
	assert_eq(presets.get_value(options, "application/product_version", ""), "")
	assert_true(presets.get_value(options, "application/modify_resources", false))
	assert_ne(presets.get_value(options, "application/icon", ""), "")
	assert_eq(presets.get_value(options, "application/product_name", ""), "Hardwire: Boot Sequence")
	assert_eq(
		presets.get_value(options, "application/file_description", ""), "Hardwire: Boot Sequence"
	)
	assert_ne(presets.get_value(options, "application/company_name", ""), "")


func test_boot_shows_the_name_with_its_subtitle() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "Hardwire: Boot Sequence")
	var boot: Control = BootScreen.new()
	add_child_autofree(boot)
	var texts: Array[String] = []
	for label: Node in boot.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_has(texts, "HARDWIRE")
	assert_has(texts, "BOOT SEQUENCE")
