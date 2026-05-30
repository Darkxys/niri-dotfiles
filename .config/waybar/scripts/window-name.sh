#!/usr/bin/env bash

niri msg --json focused-window 2>/dev/null | jq -r '
	if . == null then
		empty
	elif .app_id == "kitty" then
		"Kitty"
	elif .app_id == "google-chrome" then
		"Chrome"
	else
		.title // empty
	end
'
