class_name ArchetypeData
extends Resource
## A family of related troops (like a Yu-Gi-Oh archetype). Membership lives on TroopData.archetype.

@export var archetype_id: StringName = &""
@export var display_name: String = ""
## Accent colour (borders, chips).
@export var color: Color = Color.WHITE
## Card background tint.
@export var color_dark: Color = Color.BLACK
## Secondary highlight (emblem second tone).
@export var color_light: Color = Color.WHITE
@export var tagline: String = ""
## Pixel emblem, one string per row: '1' = accent, '2' = secondary, anything else empty.
@export var emblem: PackedStringArray = []
## Card border width in px (Forge is heavy, others thin).
@export var frame_width: int = 2
## Card background pattern id (see ArchetypePattern): embers, waves, grain, tread, dust, chevrons.
@export var pattern: StringName = &""
@export var description: String = ""
## Field synergy: while both living active troops of a side share this archetype, each gets these STAT_MOD effects.
@export var synergy: Array[EffectData] = []
