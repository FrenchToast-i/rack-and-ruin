class_name PortalSDK
extends RefCounted

# Portal hooks intentionally use each platform's official SDK API. The
# matching export preset loads that SDK; a missing SDK is always a safe no-op.

var _muted_by_portal := false
var _gameplay_active := false

func is_web() -> bool:
	# JavaScriptBridge exists only in Web exports; the null guard below keeps
	# this safe if the engine ever changes feature-tag behavior.
	return OS.has_feature("web")

func notify_loading_start() -> void:
	# Poki has a loading-finished event, but no loading-start event; CrazyGames
	# handles its loader in the host. Kept as a shared hook for the game.
	pass

func notify_loading_done() -> void:
	# Shell waits for the engine and portal SDK before dispatching load-finished.
	_js_eval("window.__rackGameReady = true; if (window.__rackNotifyLoadingFinished) window.__rackNotifyLoadingFinished();")

func gameplay_start() -> void:
	if _gameplay_active:
		return
	_gameplay_active = true
	_js_eval("if (window.__rackPokiReady) window.__rackPokiReady.then(function(ok) { if (ok && window.PokiSDK) window.PokiSDK.gameplayStart(); }); if (window.__rackCrazyGamesReady) window.__rackCrazyGamesReady.then(function(ok) { if (ok && window.CrazyGames && window.CrazyGames.SDK) window.CrazyGames.SDK.game.gameplayStart(); });")

func gameplay_stop() -> void:
	if not _gameplay_active:
		return
	_gameplay_active = false
	_js_eval("if (window.__rackPokiReady) window.__rackPokiReady.then(function(ok) { if (ok && window.PokiSDK) window.PokiSDK.gameplayStop(); }); if (window.__rackCrazyGamesReady) window.__rackCrazyGamesReady.then(function(ok) { if (ok && window.CrazyGames && window.CrazyGames.SDK) window.CrazyGames.SDK.game.gameplayStop(); });")

func set_portal_muted(muted: bool) -> void:
	_muted_by_portal = muted
	if is_web():
		_js_eval("window.__rackPortalMuted = %s;" % ("true" if muted else "false"))

func happy_time() -> void:
	# Optional Poki celebration hook; other portals do not expose this method.
	_js_eval("if (window.__rackPokiReady) window.__rackPokiReady.then(function(ok) { if (ok && window.PokiSDK) window.PokiSDK.happyTime(); });")

func is_muted_by_portal() -> bool:
	if not is_web():
		return _muted_by_portal
	var portal_muted: Variant = _js_eval("!!window.__rackPortalMuted", true)
	return _muted_by_portal or bool(portal_muted)

func set_muted_by_portal(muted: bool) -> void:
	set_portal_muted(muted)

# Copy a shareable result. The shell owns the browser path because portals run
# the game in an iframe, where navigator.clipboard needs permission the
# embedding page may not grant; its textarea fallback still works on a click.
func copy_text(text: String) -> bool:
	if is_web():
		var bridge = Engine.get_singleton("JavaScriptBridge")
		if bridge == null:
			return false
		var ok: Variant = bridge.eval("window.__rackCopy ? window.__rackCopy(%s) : false" % JSON.stringify(text), true)
		return bool(ok)
	DisplayServer.clipboard_set(text)
	return true

func _js_eval(source: String, use_global_execution_context := false) -> Variant:
	if not is_web():
		return null
	var bridge = Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return null
	return bridge.eval(source, use_global_execution_context)
