import os

import requests
from flask import Flask, request, render_template_string

APIM_URL = os.environ["APIM_URL"]
API_RESOURCE = os.environ["API_RESOURCE"]
MODEL_NAME = os.environ["MODEL_NAME"]
WEB_PORT = int(os.environ.get("WEB_PORT", "5000"))

app = Flask(__name__)

PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Cross-Tenant AI Gateway</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 16px; }
    h1 { font-size: 1.3rem; }
    textarea { width: 100%; height: 120px; padding: 10px; font-size: 1rem; box-sizing: border-box; }
    button { margin-top: 10px; padding: 10px 18px; font-size: 1rem; cursor: pointer; }
    .box { margin-top: 20px; padding: 16px; border-radius: 8px; white-space: pre-wrap; }
    .answer { background: #eef7ee; border: 1px solid #cfe6cf; }
    .error { background: #fdecec; border: 1px solid #f5c2c2; }
    .meta { color: #666; font-size: 0.85rem; margin-top: 24px; }
  </style>
</head>
<body>
  <h1>Cross-Tenant AI Gateway demo</h1>
  <p>Prompt is sent from this customer-tenant VM through the private APIM endpoint to Microsoft Foundry.</p>
  <form method="post">
    <textarea name="prompt" placeholder="Ask something...">{{ prompt or "" }}</textarea>
    <button type="submit">Send through gateway</button>
  </form>
  {% if answer %}<div class="box answer"><strong>Response:</strong>\n{{ answer }}</div>{% endif %}
  {% if error %}<div class="box error"><strong>Error:</strong>\n{{ error }}</div>{% endif %}
  <div class="meta">Endpoint: {{ apim_url }}<br />Auth: VM managed identity (no client secret)</div>
</body>
</html>
"""


def get_token():
    resp = requests.get(
        "http://169.254.169.254/metadata/identity/oauth2/token",
        params={"api-version": "2018-02-01", "resource": API_RESOURCE},
        headers={"Metadata": "true"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


@app.route("/", methods=["GET", "POST"])
def index():
    answer = None
    error = None
    prompt = ""
    if request.method == "POST":
        prompt = request.form.get("prompt", "").strip()
        try:
            token = get_token()
            resp = requests.post(
                APIM_URL,
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={
                    "model": MODEL_NAME,
                    "max_tokens": 400,
                    "messages": [{"role": "user", "content": prompt}],
                },
                timeout=60,
            )
            resp.raise_for_status()
            answer = "".join(
                block.get("text", "")
                for block in resp.json().get("content", [])
                if block.get("type") == "text"
            )
        except requests.HTTPError as exc:
            error = f"{exc.response.status_code}: {exc.response.text}"
        except Exception as exc:  # noqa: BLE001 - surface any failure to the page
            error = str(exc)
    return render_template_string(PAGE, answer=answer, error=error, prompt=prompt, apim_url=APIM_URL)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=WEB_PORT)
