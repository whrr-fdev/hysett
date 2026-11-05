#!/bin/bash
firefox https://www.gismeteo.ru/weather-petrozavodsk-3934/ &
sleep 0.5
hyprctl eval "for _,w in pairs(hl.get_windows()) do if w.class == 'firefox' then hl.dispatch(hl.dsp.focus({ workspace = w.workspace.id })) break end end"
