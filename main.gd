extends Control

# --- VARIABLES ---
@export var background_node: TextureRect
@export var day_img: Texture2D
@export var eve_img: Texture2D
@export var night_img: Texture2D

# Save File
const SAVE_PATH = "user://oceanic_history.json"

# UI References (Main Widget)
@export var input_name: LineEdit
@export var habits_container: VBoxContainer
@export var btn_happy: Button
@export var btn_neutral: Button
@export var btn_sad: Button
@export var btn_angry: Button
@export var btn_calm: Button  # <-- Make sure to link this in Inspector!

# Stats UI References
@export var stats_panel: Panel
@export var history_grid: GridContainer
@export var label_total_days: Label
@export var label_happy_days: Label
@export var label_longest_streak: Label

# State Variables
var current_mood = ""
var last_known_date = ""
var history = {} 

# Dragging
var following = false
var drag_start_position = Vector2()

func _ready():
	last_known_date = Time.get_date_string_from_system()
	check_time_and_update_theme()
	load_history()      
	load_todays_state() 

func _process(delta):
	check_time_and_update_theme()
	check_for_new_day()

# --- NEW DAY LOGIC ---
func check_for_new_day():
	var current_date = Time.get_date_string_from_system()
	if current_date != last_known_date:
		last_known_date = current_date
		reset_ui_visuals() 

func reset_ui_visuals():
	for child in habits_container.get_children():
		if child is CheckBox: child.set_pressed_no_signal(false)
	reset_mood_buttons()
	current_mood = ""

# --- SAVE SYSTEM ---
func save_today():
	var habit_data = {}
	for child in habits_container.get_children():
		if child is CheckBox:
			habit_data[child.text] = child.button_pressed
			
	var todays_data = {
		"habits": habit_data,
		"mood": current_mood
	}
	
	var today_str = Time.get_date_string_from_system()
	history[today_str] = todays_data
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(history))

func load_history():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		history = JSON.parse_string(file.get_as_text())
	else:
		history = {}

func load_todays_state():
	var today_str = Time.get_date_string_from_system()
	var habits_to_load = {}
	
	if history.has(today_str):
		habits_to_load = history[today_str].get("habits", {})
		if history[today_str].has("mood"):
			set_mood_visuals(history[today_str]["mood"])
	elif not history.is_empty():
		var last_date = history.keys().max() 
		var last_habits = history[last_date].get("habits", {})
		for h in last_habits: habits_to_load[h] = false 
	
	for child in habits_container.get_children(): child.queue_free()
	for habit_name in habits_to_load:
		add_new_habit_node(habit_name, habits_to_load[habit_name])

# --- UI LOGIC ---
func add_new_habit_node(habit_name, is_checked):
	var new_checkbox = CheckBox.new()
	new_checkbox.text = habit_name
	var my_font = load("res://assets/Montserrat-Bold.ttf")
	new_checkbox.add_theme_font_override("font", my_font)
	new_checkbox.button_pressed = is_checked
	habits_container.add_child(new_checkbox)
	new_checkbox.toggled.connect(func(x): save_today())

# --- MOOD & COLOR LOGIC (UPDATED PALETTE) ---
func reset_mood_buttons():
	# Reset all to white
	var white = Color(1,1,1)
	if btn_happy: btn_happy.modulate = white
	if btn_neutral: btn_neutral.modulate = white
	if btn_sad: btn_sad.modulate = white
	if btn_angry: btn_angry.modulate = white
	if btn_calm: btn_calm.modulate = white

func set_mood_visuals(mood_name):
	current_mood = mood_name
	
	# 1. Define the Sunset Palette
	var col_happy = Color("#F4A3B6")   # Soft Rose
	var col_neutral = Color("#B2B6D9") # Periwinkle
	var col_sad = Color("#6B76A6")     # Muted Blue
	var col_angry = Color("#A85E7D")   # Deep Mauve
	var col_calm = Color("#F8D38D")    # Golden
	
	# 2. Reset First
	reset_mood_buttons()

	# 3. Tint the active button
	if mood_name == "Happy":
		if btn_happy: btn_happy.modulate = col_happy
	elif mood_name == "Neutral":
		if btn_neutral: btn_neutral.modulate = col_neutral
	elif mood_name == "Sad":
		if btn_sad: btn_sad.modulate = col_sad
	elif mood_name == "Angry":
		if btn_angry: btn_angry.modulate = col_angry
	elif mood_name == "Calm":
		if btn_calm: btn_calm.modulate = col_calm

# --- STREAK LOGIC ---
func calculate_current_streak() -> int:
	var streak = 0
	var check_date = Time.get_date_string_from_system() 
	while true:
		if history.has(check_date):
			streak += 1
			# Go back one day logic
			var date_dict = Time.get_datetime_dict_from_datetime_string(check_date, false)
			var unix_time = Time.get_unix_time_from_datetime_dict(date_dict)
			var previous_day_unix = unix_time - 86400 
			var prev_date_dict = Time.get_datetime_dict_from_unix_time(previous_day_unix)
			
			var month_str = str(prev_date_dict.month)
			if prev_date_dict.month < 10: month_str = "0" + month_str
			
			var day_str = str(prev_date_dict.day)
			if prev_date_dict.day < 10: day_str = "0" + day_str
			
			check_date = str(prev_date_dict.year) + "-" + month_str + "-" + day_str
		else:
			break
	return streak

# --- AESTHETIC STATS LOGIC (UPDATED WITH EMOJIS) ---
func generate_statistics():
	var total_days = history.size()
	var happy_count = 0
	var habits_completed = 0
	
	# 1. Clear previous grid bubbles
	for child in history_grid.get_children():
		child.queue_free()
	
	# 2. Sort and Loop History
	var sorted_dates = history.keys()
	sorted_dates.sort()
	
	for date in sorted_dates:
		var entry = history[date]
		
		if entry.get("mood") == "Happy": happy_count += 1
		
		# --- DRAW THE BUBBLE ---
		var bubble = PanelContainer.new()
		bubble.custom_minimum_size = Vector2(35, 35) # Slightly bigger for emoji
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(50) # Circle
		style.bg_color = Color("#1a1a2e") # Dark background
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		
		# --- NEW COLOR PALETTE & EMOJIS ---
		var mood = entry.get("mood", "")
		var mood_color = Color("#546E7A") # Default Grey
		var emoji_icon = ""
		
		if mood == "Happy": 
			mood_color = Color("#F4A3B6") # Soft Rose
			emoji_icon = "😊"
		elif mood == "Neutral": 
			mood_color = Color("#B2B6D9") # Periwinkle
			emoji_icon = "😐"
		elif mood == "Sad": 
			mood_color = Color("#6B76A6") # Muted Blue
			emoji_icon = "😢"
		elif mood == "Angry": 
			mood_color = Color("#A85E7D") # Deep Mauve
			emoji_icon = "😡"
		elif mood == "Calm":
			mood_color = Color("#F8D38D") # Golden
			emoji_icon = "😌"
			
		style.border_color = mood_color
		bubble.add_theme_stylebox_override("panel", style)
		
		# Add the Emoji
		var emoji = Label.new()
		emoji.text = emoji_icon
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		bubble.add_child(emoji)
		history_grid.add_child(bubble)

	# 3. Update the "Stat Cards" Text
	if label_total_days: label_total_days.text = str(total_days)
	if label_happy_days: label_happy_days.text = str(happy_count)
	
	var current_streak = calculate_current_streak()
	if label_longest_streak: 
		label_longest_streak.text = str(current_streak) + " Days"
	
	stats_panel.visible = true

# --- BUTTON SIGNALS ---
func _on_btn_add_pressed():
	add_new_habit_node(input_name.text, false)
	input_name.text = ""
	save_today()

func _on_btn_happy_pressed(): set_mood_visuals("Happy"); save_today()
func _on_btn_neutral_pressed(): set_mood_visuals("Neutral"); save_today()
func _on_btn_sad_pressed(): set_mood_visuals("Sad"); save_today()
func _on_btn_angry_pressed(): set_mood_visuals("Angry"); save_today()
func _on_btn_calm_pressed(): set_mood_visuals("Calm"); save_today()

func _on_btn_close_pressed(): get_tree().quit()
func _on_btn_stats_pressed(): generate_statistics() 
func _on_btn_close_stats_pressed(): stats_panel.visible = false 

# --- STANDARD STUFF ---
func check_time_and_update_theme():
	var h = Time.get_time_dict_from_system().hour
	if h >= 6 and h < 16:
		background_node.texture = day_img
	elif h >= 16 and h < 20:
		background_node.texture = eve_img
	else:
		background_node.texture = night_img
	
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == 1:
		following = event.pressed
		drag_start_position = get_global_mouse_position()
	if following and event is InputEventMouseMotion:
		get_window().position += Vector2i(get_global_mouse_position() - drag_start_position)
