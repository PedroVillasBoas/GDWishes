class_name IconSet
extends Resource
## Inspector-editable icon registry 
## Every slot below is one icon used by the app
## Icons are expected to be pure white so they can be tinted at runtime via modulate

@export_group("Navigation")
@export var dashboard: Texture2D
@export var transactions: Texture2D
@export var wishes: Texture2D
@export var categories: Texture2D
@export var recurring: Texture2D
@export var settings: Texture2D

@export_group("Actions")
@export var add: Texture2D            
@export var edit: Texture2D
@export var delete: Texture2D
@export var save: Texture2D
@export var open: Texture2D          
@export var close: Texture2D        
@export var back: Texture2D           
@export var search: Texture2D
@export var confirm: Texture2D        
@export var transfer: Texture2D      

@export_group("Finance")
@export var income: Texture2D
@export var expense: Texture2D
@export var target: Texture2D        
@export var deposit: Texture2D       
@export var wallet: Texture2D        

@export_group("Status")
@export var trophy: Texture2D        
@export var cart: Texture2D        
@export var celebrate: Texture2D     
@export var welcome: Texture2D       
@export var warning: Texture2D   

@export_group("Arrows")
@export var chevron_left: Texture2D   
@export var chevron_right: Texture2D  

@export_group("Misc")
@export var particle: Texture2D       

## Returns every slot as {name: Texture2D}
## Built by reflection so adding a new @export above is the only step needed to expose a new icon to the app
func as_dictionary() -> Dictionary:
	var result := {}
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.type == TYPE_OBJECT:
			result[prop.name] = get(prop.name)
	return result
