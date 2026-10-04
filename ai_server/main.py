"""Eden Genesis Alpha 0.04 - AI 服务器
运行：python main.py
"""
from flask import Flask, request, jsonify
from npc_brain import think

app = Flask(__name__)


@app.route("/chat", methods=["POST"])
def chat():
    data = request.json or {}
    try:
        answer = think(data)
        return jsonify({"reply": answer})
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({"reply": f"(AI服务器出错: {e})", "error": str(e)}), 500


@app.route("/status", methods=["GET"])
def status():
    from memory_system import MemorySystem
    from personality import Personality
    from relationship import Relationship
    return jsonify({
        "memories": MemorySystem().top_memories(10),
        "personality": Personality().get(),
        "relationship": Relationship().people,
    })


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"ok": True})


if __name__ == "__main__":
    print("Eden Genesis AI Server (Alpha 0.04) on http://127.0.0.1:5000")
    app.run(host="127.0.0.1", port=5000, debug=False)
