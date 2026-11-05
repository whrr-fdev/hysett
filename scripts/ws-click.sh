#!/bin/bash
echo "ARGS: $@" >> /tmp/ws-click.log
hyprctl dispatch "hl.dsp.focus({ workspace = $1 })"
