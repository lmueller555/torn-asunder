extends ColorRect
## Local presentation only; the stock cancel action keeps its existing bindings.
signal cancelled
var label:Label
var detail:Label
var bar:ProgressBar
var back:Button

func build(source:String,destination:String)->void:
	color=Color("#15201c")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var centered:=CenterContainer.new()
	centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centered)
	var stack:=VBoxContainer.new()
	stack.custom_minimum_size.x=480
	stack.add_theme_constant_override("separation",12)
	centered.add_child(stack)
	label=Label.new()
	label.add_theme_font_size_override("font_size",23)
	label.text="Preparing %s\nSaved position: %s"%[destination,source]
	stack.add_child(label)
	detail=Label.new()
	detail.text="Checking the route"
	detail.add_theme_color_override("font_color",Color("#d1bb89"))
	stack.add_child(detail)
	bar=ProgressBar.new()
	bar.show_percentage=false
	bar.custom_minimum_size.y=12
	bar.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background",_tint(Color("#324039")))
	bar.add_theme_stylebox_override("fill",_tint(Color("#b9a36f")))
	stack.add_child(bar)
	back=Button.new()
	back.text="Cancel"
	back.pressed.connect(func()->void:cancelled.emit())
	stack.add_child(back)
	back.grab_focus.call_deferred()

func _tint(color:Color)->StyleBoxFlat:
	var box:=StyleBoxFlat.new()
	box.bg_color=color
	return box

func update_progress(part:int,total:int)->void:
	bar.value=100.0*part/maxi(1,total)
	detail.text="Finishing the terrain" if part>=total else "Surveying terrain · %d%%"%int(bar.value)

func _unhandled_input(event:InputEvent)->void:
	if not event.is_echo() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
