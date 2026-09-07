class_name GameInputEvents

static func movement_input() -> Vector2:
	var dir := Vector2.ZERO
	
	if Input.is_action_pressed("walk_left"):
		dir.x -= 1
	if Input.is_action_pressed("walk_right"):
		dir.x += 1
	if Input.is_action_pressed("walk_up"):
		dir.y -= 1
	if Input.is_action_pressed("walk_down"):
		dir.y += 1
		
	return dir.normalized()

static func is_movement_input() -> bool:
	return movement_input() != Vector2.ZERO

static func use_tool() -> bool:
	return Input.is_action_just_pressed("hit")
