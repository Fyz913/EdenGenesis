"""豆包大模型 API 占位。

Alpha 0.03 先用本地规则跑通整条链路；
Alpha 0.03.1 把下面 call_llm 里的注释取消、填上你的接入点 ID 即可切到真实大模型。
"""
import os


def call_llm(system_prompt: str, user_message: str) -> str:
    """调用豆包大模型。返回空字符串表示没配 key，上层会走本地规则。

    接入步骤：
    1. 在火山引擎控制台开通豆包大模型，创建推理接入点，拿到 endpoint id (ep-xxxx)。
    2. 设置环境变量：
         setx DOUBAO_API_KEY "你的api_key"
         setx DOUBAO_ENDPOINT "ep-xxxx"
    3. 取消下面注释。
    """
    api_key = os.environ.get("DOUBAO_API_KEY", "")
    endpoint = os.environ.get("DOUBAO_ENDPOINT", "")
    if not api_key or not endpoint:
        return ""

    import requests  # noqa: WPS433
    resp = requests.post(
        "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        headers={"Authorization": f"Bearer {api_key}"},
        json={
            "model": endpoint,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_message},
            ],
            "temperature": 0.8,
        },
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]["content"].strip()
