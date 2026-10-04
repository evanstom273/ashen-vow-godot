class_name CurrencyDrop
extends InteractableEntity

@export var definition: CurrencyDropDefinition
@export var amount: int = 0
var pulse: float = 0.0

func _ready() -> void:
    if definition == null: definition = CurrencyDropDefinition.new()
    super._ready()
    add_to_group("currency_drop")
    z_index = 2
    var artwork := Node2D.new()
    artwork.name = "Artwork"
    add_child(artwork)
    artwork.global_scale = Vector2.ONE * WorldScale.ART_SCALE
    artwork.draw.connect(_draw_art.bind(artwork))

func can_interact(player: Node) -> bool:
    return amount > 0 and Elevation.compatible(self, player) and global_position.distance_to(player.global_position) <= definition.pickup_radius

func get_interaction_prompt() -> String:
    return "Recover " + str(amount) + " " + definition.display_name

func interact(player: Node) -> void:
    if not can_interact(player): return
    player.add_currency(amount, definition.recovery_message)
    amount = 0
    queue_free()

func _process(delta: float) -> void:
    pulse += delta
    $Artwork.queue_redraw()

func _draw_art(artwork: Node2D) -> void:
    var color: Color = definition.color if definition != null else Color("e6b968")
    var glow: float = 0.68 + sin(pulse * 3.0) * 0.12
    artwork.draw_circle(Vector2(0, -8), 9.0 + sin(pulse * 2.0) * 1.5, Color(color, 0.18))
    artwork.draw_colored_polygon(PackedVector2Array([Vector2(0,-19),Vector2(8,-8),Vector2(0,3),Vector2(-8,-8)]), Color(color, glow))
    artwork.draw_polyline(PackedVector2Array([Vector2(0,-19),Vector2(8,-8),Vector2(0,3),Vector2(-8,-8),Vector2(0,-19)]), Color("fff0b0"), 1.5, true)
