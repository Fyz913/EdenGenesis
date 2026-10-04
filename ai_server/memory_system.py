"""长期记忆：带重要性权重、时间戳，按重要性排序。"""
import json
import time
import os

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
MEMORY_FILE = os.path.join(DATA_DIR, "npc_memory.json")


class MemorySystem:
    def __init__(self, name: str = "阿尔"):
        self.name = name
        self.data = self._load()

    def _load(self) -> dict:
        with open(MEMORY_FILE, "r", encoding="utf-8") as f:
            return json.load(f)

    def _save(self) -> None:
        with open(MEMORY_FILE, "w", encoding="utf-8") as f:
            json.dump(self.data, f, ensure_ascii=False, indent=2)

    def add_memory(self, event: str, importance: int = 1) -> None:
        self.data["memories"].append({
            "event": event,
            "importance": importance,
            "time": time.time(),
        })
        self._save()

    def top_memories(self, n: int = 5) -> list:
        """返回最重要的 n 条记忆（按 importance 倒序）"""
        sorted_m = sorted(self.data["memories"], key=lambda x: x.get("importance", 0), reverse=True)
        return sorted_m[:n]

    def get_all(self) -> dict:
        return self.data
