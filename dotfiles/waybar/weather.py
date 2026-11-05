#!/usr/bin/env python3
import json, urllib.request, time, os, sys

WMO_ICONS = {
    0: ("☀️", "Ясно"), 1: ("🌤️", "Преимущ. ясно"), 2: ("⛅", "Переменная облачность"), 3: ("☁️", "Пасмурно"),
    45: ("🌫️", "Туман"), 48: ("🌫️", "Изморозь"),
    51: ("🌦️", "Слабая морось"), 53: ("🌦️", "Морось"), 55: ("🌧️", "Сильная морось"),
    56: ("🌧️", "Ледяная морось"), 57: ("🌧️", "Сильная ледяная морось"),
    61: ("🌦️", "Слабый дождь"), 63: ("🌧️", "Дождь"), 65: ("🌧️", "Сильный дождь"),
    66: ("🌧️", "Ледяной дождь"), 67: ("🌧️", "Сильный ледяной дождь"),
    71: ("🌨️", "Слабый снег"), 73: ("🌨️", "Снег"), 75: ("❄️", "Сильный снег"), 77: ("❄️", "Снежные зерна"),
    80: ("🌦️", "Ливень"), 81: ("🌧️", "Сильный ливень"), 82: ("⛈️", "Очень сильный ливень"),
    85: ("🌨️", "Снегопад"), 86: ("❄️", "Сильный снегопад"),
    95: ("⛈️", "Гроза"), 96: ("⛈️", "Гроза с градом"), 99: ("⛈️", "Сильная гроза с градом")
}

def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read().decode("utf-8"))

def main():
    cache_file = os.path.expanduser("~/.cache/waybar_weather.json")
    cache_printed = False
    try:
        with open(cache_file, "r") as f:
            print(f.read(), flush=True)
            cache_printed = True
    except Exception:
        pass

    lat, lon = "61.785", "34.3469"
    url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m&wind_speed_unit=ms"
    for _ in range(6):
        try:
            data = get_json(url)["current"]
            t = round(data["temperature_2m"])
            feels = round(data["apparent_temperature"])
            code = data["weather_code"]
            wind = data["wind_speed_10m"]
            icon, desc = WMO_ICONS.get(code, ("🌡️", "Погода"))
            sign = "+" if t > 0 else ""
            fsign = "+" if feels > 0 else ""
            text = f"{icon} {sign}{t}°C"
            now_str = time.strftime("%d.%m.%Y %H:%M")
            tooltip = f"<b>Петрозаводск: {desc}</b>\nОщущается как: {fsign}{feels}°C\nВетер: {wind} м/с\n<span color='#888888'>────────────────────</span>\n<small>Обновлено: {now_str}</small>"
            res = json.dumps({"text": text, "tooltip": tooltip}, ensure_ascii=False)
            print(res, flush=True)
            try:
                with open(cache_file, "w") as f:
                    f.write(res)
            except Exception:
                pass
            return
        except Exception:
            time.sleep(5)
    if not cache_printed:
        print(json.dumps({"text": "🌡️ --°C", "tooltip": "Нет данных о погоде"}, ensure_ascii=False), flush=True)

if __name__ == "__main__":
    main()
