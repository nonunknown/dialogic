@tool
class_name DialogicVariableEvent
extends DialogicEvent

## Event that allows changing a dialogic variable or a property of an autoload.


enum Operations {Set, Add, Substract, Multiply, Divide}

## Settings

## Name/Path of the variable that should be changed.
var name: String = ""
## The operation to perform.
var operation: int = Operations.Set
## The value that is used. Can be a variable as well.
var value: String = ""
## If true, a random number between [random_min] and [random_max] is used instead of [value].
var random_enabled: bool = false
var random_min: int = 0
var random_max: int = 100


################################################################################
## 						EXECUTE
################################################################################

func _execute() -> void:
	if name:
		var orig = dialogic.VAR.get_variable(name)
		var the_value = value
		if value.begins_with("{"):
			the_value = dialogic.VAR.get_variable(value)
		if random_enabled:
			the_value = randi()%(random_max-random_min)+random_min
		
		if orig != null:
			if Dialogic.has_subsystem('History'):
				if Dialogic.History.full_history_enabled:
					Dialogic.History.full_history[0]['previous_value'] = orig
			
			if operation != Operations.Set and orig.is_valid_float() and value.is_valid_float():
				orig = orig.to_float()
				the_value = value.to_float()
				match operation:
					Operations.Add:
						dialogic.VAR.set_variable(name, str(orig+the_value))
					Operations.Substract:
						dialogic.VAR.set_variable(name, str(orig-the_value))
					Operations.Multiply:
						dialogic.VAR.set_variable(name, str(orig*the_value))
					Operations.Divide:
						dialogic.VAR.set_variable(name, str(orig/the_value))
			elif operation == Operations.Set:
				dialogic.VAR.set_variable(name, str(the_value))
			else:
				printerr("Dialogic: Set Variable event failed because one value wasn't a float!")
	finish()


func get_required_subsystems() -> Array:
	return [
				{'name':'VAR',
				'subsystem': get_script().resource_path.get_base_dir().path_join('subsystem_variables.gd'),
				'settings': get_script().resource_path.get_base_dir().path_join('variables_editor/settings_variables.tscn'),
				},
			]


################################################################################
## 						INITIALIZE
################################################################################

func _init() -> void:
	event_name = "Set Variable"
	set_default_color('Color1')
	event_category = Category.Godot
	event_sorting_index = 0
	expand_by_default = false


################################################################################
## 						SAVING/LOADING
################################################################################

func to_text() -> String:
	var string = "VAR "
	if name:
		string += "{" + name + "}"
		match operation:
			Operations.Set:
				string+= " = "
			Operations.Add:
				string+= " += "
			Operations.Substract:
				string+= " -= "
			Operations.Multiply:
				string+= " *= "
			Operations.Divide:
				string+= " /= "
		string += value
	if random_enabled:
		string += ' [random="True"'
		if random_min != 0:
			string += ' min="'+str(random_min)+'"' 
		if random_max != 100:
			string += ' max="'+str(random_max)+'"' 
		string += "]"
	return string


func from_text(string:String) -> void:
	var reg = RegEx.new()
	reg.compile("VAR (?<name>[^=+\\-*\\/]*)(?<operation>=|\\+=|-=|\\*=|\\/=)(?<value>[^\\[\\n]*)(?<shortcode>\\[.*)?")
	var result = reg.search(string)
	name = result.get_string('name').strip_edges().replace("{", "").replace("}", "")
	match result.get_string('operation').strip_edges():
		'=':
			operation = Operations.Set
		'-=':
			operation = Operations.Substract
		'+=':
			operation = Operations.Add
		'*=':
			operation = Operations.Multiply
		'/=':
			operation = Operations.Divide
	value = result.get_string('value').strip_edges()
	
	if !result.get_string('shortcode').is_empty():
		var shortcodeparams = parse_shortcode_parameters(result.get_string('shortcode'))
		random_enabled = true if shortcodeparams.get('random', "True") == "True" else false
		random_min = DialogicUtil.logical_convert(shortcodeparams.get('min', 0))
		random_max = DialogicUtil.logical_convert(shortcodeparams.get('max', 100))


func is_valid_event(string:String) -> bool:
	return string.begins_with('VAR ')


################################################################################
## 						EDITOR REPRESENTATION
################################################################################

func build_event_editor():
	add_header_edit('name', ValueType.ComplexPicker, '', '', 
			{'suggestions_func' 	: get_var_suggestions, 
			'editor_icon' 			: ["ClassList", "EditorIcons"]})
	add_header_edit('operation', ValueType.FixedOptionSelector, '', '', {
		'selector_options': [
			{
				'label': 'to be',
				'icon': load("res://addons/dialogic/Editor/Images/Dropdown/set.svg"),
				'value': Operations.Set
			},
			{
				'label': 'to itself plus',
				'icon': load("res://addons/dialogic/Editor/Images/Dropdown/plus.svg"),
				'value': Operations.Add
			},
			{
				'label': 'to itself minus',
				'icon': load("res://addons/dialogic/Editor/Images/Dropdown/minus.svg"),
				'value': Operations.Substract
			},
			{
				'label': 'to itself multiplied by',
				'icon': load("res://addons/dialogic/Editor/Images/Dropdown/multiply.svg"),
				'value': Operations.Multiply
			},
			{
				'label': 'to itself divided by',
				'icon': load("res://addons/dialogic/Editor/Images/Dropdown/divide.svg"),
				'value': Operations.Divide
			}
		]
	}, '!name.is_empty()')
	add_header_edit('value', ValueType.ComplexPicker, '', '', 
			{'suggestions_func'	: get_value_suggestions, 
			'editor_icon' 		: ["Variant", "EditorIcons"], }, 
			'!name.is_empty() and not random_enabled')
	add_header_label('a random integer', 'random_enabled')
	add_body_edit('random_enabled', ValueType.Bool, 'Use Random Integer:', '', {}, '!name.is_empty()')
	add_body_edit('random_min', ValueType.Integer, 'Min:', '', {}, '!name.is_empty() and random_enabled')
	add_body_edit('random_max', ValueType.Integer, 'Max:', '', {}, '!name.is_empty() and random_enabled')

func get_var_suggestions(filter:String) -> Dictionary:
	var suggestions := {}
	
	if filter:
		suggestions[filter] = {'value':filter, 'editor_icon':["GuiScrollArrowRight", "EditorIcons"]}
	var vars: Dictionary = DialogicUtil.get_project_setting('dialogic/variables', {})
	for var_path in list_variables(vars):
		suggestions[var_path] = {'value':var_path, 'editor_icon':["ClassList", "EditorIcons"]}
	return suggestions


func list_variables(dict, path = "") -> Array:
	var array := []
	for key in dict.keys():
		if typeof(dict[key]) == TYPE_DICTIONARY:
			array.append_array(list_variables(dict[key], path+key+"."))
		else:
			array.append(path+key)
	return array

func get_value_suggestions(filter:String) -> Dictionary:
	var suggestions := {}
	
	if filter:
		suggestions[filter] = {'value':filter, 'editor_icon':["GuiScrollArrowRight", "EditorIcons"]}
	var vars: Dictionary = DialogicUtil.get_project_setting('dialogic/variables', {})
	for var_path in list_variables(vars):
		suggestions[var_path] = {'value':var_path, 'editor_icon':["ClassList", "EditorIcons"]}
	return suggestions
