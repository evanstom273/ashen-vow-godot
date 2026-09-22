@tool
class_name CurrencyDropDefinition
extends Resource

enum DeliveryMode { IMMEDIATE, PICKUP }

@export var delivery_mode: DeliveryMode = DeliveryMode.IMMEDIATE
@export_range(0, 1000000, 1) var fixed_amount: int = 0
@export_range(0, 1000000, 1) var minimum_amount: int = 0
@export_range(0, 1000000, 1) var maximum_amount: int = 0
@export_range(0, 100, 0.01) var amount_multiplier: float = 1.0
@export_range(1, 500, 1) var pickup_radius: float = 48.0
@export var display_name: String = "Embers"
@export var icon: Texture2D
@export var color: Color = Color("e6b968")
@export var recovery_message: String = "Embers recovered"
@export var replace_previous_drop: bool = true

func roll_amount() -> int:
    var upper: int = maximum_amount if maximum_amount > 0 else minimum_amount
    var amount: int = fixed_amount if upper <= minimum_amount else randi_range(minimum_amount, upper)
    return maxi(0, roundi(amount * amount_multiplier))
