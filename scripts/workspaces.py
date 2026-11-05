#!/usr/bin/env python3
import json, subprocess

def main():
    try:
        out = subprocess.check_output(["hyprctl", "-j", "workspaces"], text=True)
        workspaces = json.loads(out)
        workspaces.sort(key=lambda w: w["id"])
        result = []
        for ws in workspaces:
            result.append({
                "name": str(ws["id"]),
                "tooltip": ws.get("name", ""),
                "class": "active" if ws.get("active") else ""
            })
        print(json.dumps(result))
    except Exception:
        print(json.dumps([]))

if __name__ == "__main__":
    main()
