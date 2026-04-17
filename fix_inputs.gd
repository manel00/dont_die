extends SceneTree

func _init():
	var input = ["weapon_0", "weapon_1", "weapon_2", "weapon_3", "weapon_4"]
	for i in range(5):
		var events = []
		var ev1 = InputEventKey.new()
		ev1.keycode = 48 + i # KEY_0 to KEY_4
		events.append(ev1)
		
		var ev2 = InputEventKey.new()
		ev2.keycode = 4194439 + i # KEY_KP_0 to KEY_KP_4
		events.append(ev2)
		var setting_name = "input/" + input[i]
		ProjectSettings.set_setting(setting_name, {"deadzone": 0.5, "events": events})
	ProjectSettings.save()
	print("Input maps updated successfully!")
	quit()
