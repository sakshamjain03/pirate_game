extends GutTest

# test_ui_icons.gd
# M15.5 Requirement 1.4 — UIIcons is the single lookup point for every UI icon
# texture; every registered key must resolve to a real, loadable Texture2D
# rather than failing silently at runtime inside some UI scene.

const _EXPECTED_KEYS := [
	"gold", "wood", "iron", "rum", "health", "notoriety", "cannon_ready",
]

func test_every_registered_icon_key_loads_a_real_texture():
	for key in _EXPECTED_KEYS:
		var tex := UIIcons.get_icon(key)
		assert_not_null(tex, "UIIcons.get_icon('%s') should return a texture" % key)
		if tex:
			assert_true(tex is Texture2D, "UIIcons.get_icon('%s') should be a Texture2D" % key)

func test_unregistered_key_returns_null_not_an_error():
	assert_null(UIIcons.get_icon("not_a_real_key"))
