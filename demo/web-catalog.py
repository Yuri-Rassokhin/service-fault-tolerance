from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from pathlib import Path
import socket
import os

app = FastAPI()

RESILIENT_DIR = Path("/resilient")

@app.get("/", response_class=HTMLResponse)
def root():
    hostname = socket.gethostname()

    entries = []
    if RESILIENT_DIR.exists():
        for p in sorted(RESILIENT_DIR.iterdir()):
            if p.is_dir():
                entries.append(f"[DIR]  {p.name}")
            else:
                entries.append(f"[FILE] {p.name} ({p.stat().st_size} bytes)")
    else:
        entries.append("/resilient does not exist")

    html = f"""
    <html>
    <head>
        <title>Fault Tolerant Service</title>
        <style>
            body {{
                font-family: monospace;
                background: #111;
                color: #eee;
            }}
            h2 {{ color: #7dd3fc; }}
            pre {{
                background: #000;
                padding: 10px;
                border: 1px solid #333;
            }}
        </style>
    </head>
    <body>
        <h2>Fault Tolerant Service</h2>
        <b>Active Node:</b> {hostname}<br>
        <b>Directory:</b> /resilient
        <br><br>
        <pre>
{os.linesep.join(entries)}
        </pre>
    </body>
    </html>
    """
    return html
