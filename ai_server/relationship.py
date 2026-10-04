"""关系系统：记录 NPC 对每个玩家/人物的好感度。"""
import json
import os

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
FILE = os.path.join(DATA_DIR, "relationship.json")


class Relationship:
    def __init__(self):
        with open(FILE, "r", encoding="utf-8") as f:
            self.people = json.load(f)

    def _save(self):
        with open(FILE, "w", encoding="utf-8") as f:
            json.dump(self.people, f, ensure_ascii=False, indent=2)

    def update(self, name: str, delta: int) -> None:
        self.people[name] = self.people.get(name, 0) + delta
        self._save()

    def get_value(self, name: str) -> int:
        return self.people.get(name, 0)

    def level(self, name: str) -> str:
        v = self.get_value(name)
        if v > 80:
            return "亲密朋友"
        if v > 40:
            return "朋友"
        if v < 0:
            return "敌人"
        return "陌生人"
