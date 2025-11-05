class_name AnimationHelper

extends AnimationTree

func wait_for_state_enter(state_machine: AnimationNodeStateMachinePlayback, state_name: String) -> void:
	while !(state_machine.get_current_node() == state_name):
		await get_tree().process_frame
		
func wait_for_state_exit(state_machine: AnimationNodeStateMachinePlayback, state_name: String) -> void:
	while state_machine.get_current_node() == state_name:
		await get_tree().process_frame
		
func fade_combat_blend_out(animation_tree: AnimationTree, animation_node_blend2: AnimationNodeBlend2):
	var blend = animation_tree.get("parameters/CombatBlend/blend_amount")
	while blend > 0.01:
		blend -= 1.5 * get_process_delta_time()
		blend = max(blend, 0.0)
		animation_tree.set("parameters/CombatBlend/blend_amount", blend)
		await get_tree().process_frame
	animation_tree.set("parameters/CombatBlend/blend_amount", 0.0)
		

func fade_combat_blend_in(animation_tree: AnimationTree, animation_node_blend2: AnimationNodeBlend2):
	var blend = animation_tree.get("parameters/CombatBlend/blend_amount")
	while blend < 0.99:
		blend = lerp(blend, 1.0, get_process_delta_time() * 3.0)
		animation_tree.set("parameters/CombatBlend/blend_amount", blend)
		await get_tree().process_frame
	animation_tree.set("parameters/CombatBlend/blend_amount", 1.0)
