extends Node

# Raza seleccionada en la pantalla de selección.
# Null si se arranca directamente desde world.tscn en el editor.
var selected_race = null    # RaceData en tiempo de ejecución
var selected_gender: String = "m"  # "m" o "f"
