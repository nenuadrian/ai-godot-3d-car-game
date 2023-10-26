extends CharacterBody3D
@onready var raycast_sensor = $"RayCastSensor3D"
@onready var goal = $"../Goal"

const SPEED = 3.0
const TURN_SENS = 2.0

var best_goal_distance := 10000.0
var move_action := 0.0
var turn_action := 0.0
var y_velo = -3
var grounded = true
var done = false
var move_vec := Vector3(0,0,0)
var needs_reset = false

var _reward = 0.0
var _heuristic := "player"
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var _original_position = Vector3(0,0,0);

func _ready():
	raycast_sensor.activate()
	_original_position = transform.origin;
	reset()

func reset_best_goal_distance():
	best_goal_distance = position.distance_to(goal.position) 

func get_move_vec() -> Vector3:
	if _heuristic == "model":
		return Vector3(
			0,
			0,
			clamp(move_action, -1.0, 0.5)
		)
		
	var move_vec := Vector3(
		0,
		0,
		clamp(Input.get_action_strength("move_backwards") - Input.get_action_strength("move_forwards"),-1.0, 0.5)
	)
	return move_vec

func get_turn_vec() -> float:
	if _heuristic == "model":
		return turn_action
	var rotation_amount = Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
	return rotation_amount
	
func _physics_process(delta):
	if position.distance_to(goal.position) < 1.3 or transform.origin.y < -1:
		done = true
		needs_reset = true
		
	if needs_reset:
		needs_reset = false
		reset()
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	grounded = is_on_floor()
	
	move_vec *= 0.0
	move_vec = get_move_vec()
	#move_vec = move_vec.normalized()
	move_vec = move_vec.rotated(Vector3(0, 1, 0), rotation.y)
	move_vec *= SPEED
	move_vec.y = y_velo
	set_velocity(move_vec)
	set_up_direction(Vector3(0, 1, 0))
	move_and_slide()
   
	rotation.y += deg_to_rad(get_turn_vec() * TURN_SENS)
	
	update_reward()

func reset():
	rotation.y = deg_to_rad(randf_range(20,20))
	set_position(_original_position)
	reset_best_goal_distance()
	
func update_reward():
	_reward -= 0.01 # step penalty
	_reward += shaping_reward()

func get_reward():
	var current_reward = _reward
	_reward = 0 # reset the reward to zero checked every decision step
	return current_reward
	
func shaping_reward():
	var s_reward = 0.0
	var goal_distance = 0
	goal_distance = position.distance_to(goal.position)
	if goal_distance < best_goal_distance:
		s_reward += best_goal_distance - goal_distance
		best_goal_distance = goal_distance
		
	s_reward /= 1.0
	return s_reward   
		
func get_done():
	return done
	
func set_done_false():
	done = false
	
func set_action(action):
	move_action = action["move"][0]
	turn_action = action["turn"][0]

func get_obs():
	var goal_distance = 0.0
	var goal_vector = Vector3.ZERO
	goal_distance = position.distance_to(goal.position)
	goal_vector = (goal.position - position).normalized()
	
	goal_vector = goal_vector.rotated(Vector3.UP, -rotation.y)
	
	#goal_distance = clamp(goal_distance, 0.0, 20.0)
	var obs = []
	obs.append_array([move_vec.x/SPEED,
					move_vec.y/y_velo,
					move_vec.z/SPEED])
	obs.append_array([goal_distance/20.0,
					goal_vector.x, 
					goal_vector.y, 
					goal_vector.z])
	obs.append(grounded)
	obs.append_array(raycast_sensor.get_observation())
	
	return {
		"obs": obs,
	}

func get_obs_space():
	# typs of obs space: box, discrete, repeated
	return {
		"obs": {
			"size": [len(get_obs()["obs"])],
			"space": "box"
			}
		}
		
func set_heuristic(heuristic):
	self._heuristic = heuristic

func get_obs_size():
	return len(get_obs())
	
func zero_reward():
	_reward = 0
	
 
func get_action_space():
	return {
		"move" : {
			"size": 1,
			"action_type": "continuous"
		},        
		"turn" : {
			"size": 1,
			"action_type": "continuous"
		},
	}
