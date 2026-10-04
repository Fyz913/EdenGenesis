"""NPC 大脑：长期记忆 + 人格 + 关系 → 生成态度化回复。"""
from memory_system import MemorySystem
from personality import Personality
from relationship import Relationship
import llm_api


# 关键词 → 关系变化
KIND_WORDS = ["谢谢", "感谢", "你真好", "朋友", "帮忙", "谢谢你"]
HELP_WORDS = ["帮你", "一起", "给你", "礼物", "送你", "这是给你的"]
HOSTILE_WORDS = ["打", "杀", "滚", "讨厌", "敌人", "垃圾", "废物"]
# 重要事件触发关键词
BIG_EVENTS = {
    "铁矿": ("玩家帮助我找到铁矿", 10),
    "救命": ("玩家救了我一命", 20),
    "村庄": ("玩家为村庄做了贡献", 15),
}


def think(data: dict) -> str:
    message = (data.get("message") or "").strip()
    speaker = data.get("speaker", "玩家")

    mem = MemorySystem()
    per = Personality()
    rel = Relationship()

    name = mem.get_all().get("name", "阿尔")
    job = mem.get_all().get("job", "铁匠")

    # 1) 先判断玩家这句话的性质，更新关系 / 人格 / 记忆
    rel_delta = 0
    importance = 1
    event_text = f"玩家说: {message}"

    if any(w in message for w in HOSTILE_WORDS):
        rel_delta = -30
        importance = 5
        event_text = f"玩家对我发火：{message}"
        per.change("信任", -5)
    elif any(w in message for w in HELP_WORDS):
        rel_delta = 10
        importance = 5
        event_text = f"玩家给了我帮助：{message}"
        per.change("信任", 3)
        per.change("善良", 1)
    elif any(w in message for w in KIND_WORDS):
        rel_delta = 5
        importance = 2
        event_text = f"玩家友善地说：{message}"
        per.change("信任", 1)

    # 触发重大事件记忆
    for keyword, (ev, imp) in BIG_EVENTS.items():
        if keyword in message:
            event_text = ev
            importance = imp
            rel_delta = max(rel_delta, 15)

    if rel_delta:
        rel.update(speaker, rel_delta)
    mem.add_memory(event_text, importance)

    # 2) 根据关系等级 + 记忆 + 人格生成回复
    level = rel.level(speaker)
    rel_val = rel.get_value(speaker)
    top = mem.top_memories(3)
    dominant = per.dominant_trait()

    # 3) 尝试大模型（配了 key 就用）
    system_prompt = (
        f"你是{name}，{mem.get_all().get('age',32)}岁，{job}。"
        f"性格偏向：{per.get()}。主导性格：{dominant}。"
        f"玩家和你的关系：{level}（好感度 {rel_val}）。"
        f"你记得最重要的几件事：{[m['event'] for m in top]}。"
        "用一两句简短自然的中文回答，像游戏 NPC，不要说你是 AI。"
    )
    try:
        llm_reply = llm_api.call_llm(system_prompt, message)
    except Exception as e:
        llm_reply = ""
        print(f"[LLM] fallback: {e}")
    if llm_reply:
        return llm_reply

    # 4) 本地规则：按关系等级分流
    if level == "亲密朋友":
        if "记得" in message or "认识" in message:
            return f"当然记得。{top[0]['event'] if top else '我们一起经历过很多'}。你是我最信任的朋友。"
        if "你好" in message or not message:
            return f"欢迎回来，老朋友。今天想打把什么工具？"
        return f"嗯，{message}——你说的我都信。我们一起想办法。"
    if level == "朋友":
        if "你好" in message:
            return f"你好啊。最近手头的活忙完了，有空一起喝一杯？"
        if "工作" in message or "做什么" in message:
            return f"我是{job}。最近矿上产量不错，多亏了你之前帮忙。"
        if "记得" in message:
            return f"记得。{top[0]['event'] if top else '我们算认识一阵了'}。"
        return f"嗯……{message}。你是个靠谱的人，我信你。"
    if level == "敌人":
        return "我不想和你说话。走开。"
    # 陌生人
    if "你好" in message:
        return f"你好，我是{name}，村里的{job}。我们刚认识吧？"
    if "工作" in message or "做什么" in message:
        return f"我是{job}，正在打工具。没什么特别的事别打扰我。"
    if "记得" in message:
        return "我们好像还没那么熟。"
    return f"嗯……{message}。我得想想再说。"
