extends GutTest

## M12 Task 5 — protects the one convention design.md calls out explicitly:
## a dynamic string's template must be translated first, then interpolated
## (`tr("Notoriety: %.1f") % val`), never the interpolated result looked up
## as a translation key (`tr("Notoriety: %.1f" % val)`), which would need a
## separate CSV entry for every possible numeric value.

const TEST_LOCALE := "xx"

var _previous_locale: String


func before_each() -> void:
	_previous_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_previous_locale)


func test_template_is_translated_before_interpolation() -> void:
	var translation := Translation.new()
	translation.locale = TEST_LOCALE
	translation.add_message("Notoriety: %.1f", "Notoriedad: %.1f")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(TEST_LOCALE)

	var result := tr("Notoriety: %.1f") % 4.5

	assert_eq(result, "Notoriedad: 4.5")
	TranslationServer.remove_translation(translation)


func test_missing_translation_falls_back_to_the_key_itself() -> void:
	TranslationServer.set_locale(TEST_LOCALE)
	assert_eq(tr("Some Untranslated Key"), "Some Untranslated Key")


func test_en_translation_resource_loads_and_is_registered() -> void:
	var translation: Translation = load("res://translations/en.en.translation")
	assert_not_null(translation)
	assert_true(ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()).has(
		"res://translations/en.en.translation"))
