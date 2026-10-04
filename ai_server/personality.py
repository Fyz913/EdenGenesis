"""人格系统：价值观会随经历变化。"""
import json
import os

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
FILE = os.path.join(DATA_DIR, "npc_personality.json")


class Personality:
    def __init__(self):
        with open(FILE, "r", encoding="utf-8") as f:
            self.values = json.load(f)

    def _save(self):
        with open(FILE, "w", encoding="utf-8") as f:
            json.dump(self.values, f, ensure_ascii=False, indent=2)

    def change(self, key: str, delta: int) -> None:
        if key not in self.values:
            self.values[key] = 50
        self.values[key] = max(0, min(100, self.values[key] + delta))
        self._save()

    def get(self) -> dict:
        return dict(self.values)

    def dominant_trait(self) -> str:
        return max(self.values, key=self.values.get)
