class_name ModalBackdrop
extends ColorRect
## The window-sized backdrop behind a Modal's panel. A docked window's lets clicks through to the
## game (`mouse_filter` ignore); with `takes_mouse_while_dragging` it takes the mouse only while a
## stack is being dragged, so that a drop beside the panel still reaches it.

var takes_mouse_while_dragging := false


func _notification(what: int) -> void:
	if not takes_mouse_while_dragging:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		mouse_filter = Control.MOUSE_FILTER_STOP
	elif what == NOTIFICATION_DRAG_END:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
