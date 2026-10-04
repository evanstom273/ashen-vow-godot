@tool
class_name ImbueDelivery
extends SpellDeliveryDefinition
@export var recipient: String = "opposite"
@export var bonus_damage: DamageProfile
@export var weapon_color: Color = Color("a4dcff")

func kind() -> StringName:
	return &"imbue"
