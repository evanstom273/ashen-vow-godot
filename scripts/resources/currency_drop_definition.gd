@tool
class_name CurrencyDropDefinition
extends Resource

enum DeliveryMode { IMMEDIATE, PICKUP }

@export var delivery_mode: DeliveryMode = DeliveryMode.IMMEDIATE
@export_range(0, 1000000, 1) var fixed_amount: int = 0
@export_range(0, 1000000, 1) var minimum_amount: int = 0
@export_range(0, 1000000, 1) var maximum_amount: int = 0
@export_range(0, 100, 0.01) var amount_multiplier: float = 1.0
## World units: 1.5 metres at the regional scale.
@export_range(1, 2000, 1) var pickup_radius: float = 192.0
@export var display_name: String = "Embers"
@export var icon: Texture2D
@export var color: Color = Color("e6b968")
@export var recovery_message: String = "Embers recovered"
@export_group("Legacy metadata (data only)")
## Session recovery always replaces the player's previous drop. World/enemy rewards
## are independent; this retained serialization field no longer controls ownership.
@export var replace_previous_drop: bool = true

func roll_amount() -> int:
    var upper: int = maximum_amount if maximum_amount > 0 else minimum_amount
    var amount: int = randi_range(minimum_amount, maxi(minimum_amount, upper)) if upper > 0 else fixed_amount
    return maxi(0, roundi(amount * amount_multiplier))
