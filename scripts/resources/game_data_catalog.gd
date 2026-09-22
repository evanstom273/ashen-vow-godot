@tool
class_name GameDataCatalog
extends Resource
## Inspector index. Scene definitions remain the authority for spawned actors.
@export var classes: Array[ClassDefinition] = []
@export var weapons: Array[WeaponDefinition] = []
@export var enemies: Array[EnemyDefinition] = []
@export var bosses: Array[BossDefinition] = []
@export var spells: Array[SpellDefinition] = []
@export var utilities: Array[UtilityDefinition] = []
@export var weapon_loadouts: Array[WeaponLoadoutDefinition] = []
@export var spell_loadouts: Array[SpellLoadoutDefinition] = []
@export var utility_loadouts: Array[UtilityLoadoutDefinition] = []
@export var currencies: Array[CurrencyDefinition] = []
@export var shrines: Array[ShrineDefinition] = []
