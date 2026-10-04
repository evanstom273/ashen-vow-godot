extends Node
## One authoritative pause/input owner. Closing an old menu cannot unpause a new one.
var _owner: WeakRef

func acquire(node: Node) -> bool:
	var existing: Variant = _owner.get_ref() if _owner != null else null
	if is_instance_valid(existing) and existing != node: return false
	_owner = weakref(node)
	get_tree().paused = true
	if not node.tree_exiting.is_connected(release.bind(node)):
		node.tree_exiting.connect(release.bind(node), CONNECT_ONE_SHOT)
	return true

func release(node: Node) -> void:
	if _owner == null: return
	var existing: Variant = _owner.get_ref() if _owner != null else null
	if is_instance_valid(existing) and existing != node: return
	_owner = null
	get_tree().paused = false

func clear() -> void:
	_owner = null
	get_tree().paused = false
