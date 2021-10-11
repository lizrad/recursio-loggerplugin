tool
extends EditorPlugin


const logger_plugin_scene = preload("res://addons/recursio-loggerplugin/LoggerPlugin.tscn")
const module_config_scene = preload("res://addons/recursio-loggerplugin/Module.tscn")
const module_mode_toggle_scene = preload("res://addons/recursio-loggerplugin/ModuleModeToggle.tscn")


var logger_plugin_instance

var config

var modes = ["VERBOSE","DEBUG", "INFO", "WARN", "ERROR"]

func _enter_tree():
	logger_plugin_instance = logger_plugin_scene.instance()
	# Add the main panel to the editor's main viewport.
	get_editor_interface().get_editor_viewport().add_child(logger_plugin_instance)
	# Hide the main panel. Very much required.
	make_visible(false)

var time_between_config_reads = 5.0
var time_to_next_config_read

func _ready():
	_read_config_file()
	time_to_next_config_read = time_between_config_reads

func _process(delta):
	time_to_next_config_read-=delta
	if time_to_next_config_read <=0:
		time_to_next_config_read = time_between_config_reads
		for module in logger_plugin_instance.get_node("ModulesBackground/ModulesScrollContainer/Modules").get_children():
			module.queue_free()
		_read_config_file()

func _read_config_file():
	config = ConfigFile.new()
	var err = config.load("res://addons/recursio-loggerplugin/loggerconfig.ini")
	if err != OK:
		print("ERROR: Could not load config file!")
	else:
		_add_modes()
		for module in config.get_sections():
			_add_new_module(module)
	_save_settings()


func _add_modes():
	var module_instance = module_config_scene.instance()
	module_instance.get_node("ModuleName").text = "Modes:"
	for mode in modes:
		var label: Label = Label.new()
		label.text = mode
		module_instance.add_child(label)
	logger_plugin_instance.get_node("ModulesBackground/ModulesScrollContainer/Modules").add_child(module_instance)
	

func _add_new_module(module):
	var module_instance = module_config_scene.instance()
	module_instance.get_node("ModuleName").text = module
	for mode in modes:
		var toggle = module_mode_toggle_scene.instance()
		if config.has_section_key(module, mode):
			toggle.pressed = config.get_value(module, mode)
		else:
			toggle.pressed = true
			config.set_value(module, mode, true)
		toggle.connect("toggled",self,"_on_module_button_toggled", [module,mode])
		module_instance.add_child(toggle)
	logger_plugin_instance.get_node("ModulesBackground/ModulesScrollContainer/Modules").add_child(module_instance)

func _save_settings():
	config.save("res://addons/recursio-loggerplugin/loggerconfig.ini")
	_save_config_file()


#TODO: this is hacky af
func _save_config_file():
	var logger_config = ConfigFile.new()
	var section = "logger"
	logger_config.set_value(section, "default_output_level",0)
	logger_config.set_value(section, "default_output_strategies",[ 1, 1, 1, 1, 1 ])
	logger_config.set_value(section, "default_logfile_path", "user://%s.log" % ProjectSettings.get_setting("application/config/name"))
	logger_config.set_value(section, "max_memory_size", 30)
	var external_sink = {
		"path": "user://%s.log" % ProjectSettings.get_setting("application/config/name"),
		"queue_mode": 0
		}
	logger_config.set_value(section, "external_sinks", [external_sink])
	var modules = []
	for module in config.get_sections():
		var module_entry = {}
		module_entry["external_sink"]=external_sink
		module_entry["name"] = module
		module_entry["output_level"]=1
		var output_strategies = []
		for mode in modes:
			output_strategies.append(config.get_value(module,mode) as int)
		module_entry["output_strategies"] = output_strategies
		modules.append(module_entry)
	logger_config.set_value(section, "modules", modules)
	logger_config.save("res://addons/recursio-loggerplugin/logger.cfg")

func _on_module_button_toggled(active: bool, module:String, mode:String):
	config.set_value(module, mode, active)
	_save_settings()

func _exit_tree():
	if logger_plugin_instance:
		logger_plugin_instance.queue_free()
func has_main_screen():
	return true
func make_visible(visible):
	if logger_plugin_instance:
		logger_plugin_instance.visible = visible
func get_plugin_name():
	return "Logger Config"
func get_plugin_icon():
	return get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")
