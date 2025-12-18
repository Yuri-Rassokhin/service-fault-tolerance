#!/usr/bin/env python3
import subprocess
import os
from fastapi import FastAPI, Response
from fastapi.responses import HTMLResponse
from pathlib import Path

MOUNT_POINT = "/resilient"
DRBD_DEVICE = "/dev/drbd0"
RESOURCE = "r0"

app = FastAPI()


def drbd_role():
    """Return DRBD role: Primary or Secondary."""
    out = subprocess.getoutput(f"drbdsetup status {RESOURCE}")
    if "role:Primary" in out:
        return "Primary"
    return "Secondary"


def promote_if_needed():
    """Promote DRBD to Primary and mount FS if not mounted."""
    role = drbd_role()
    if role == "Primary":
        return True  # already primary

    # Try force-promoting
    subprocess.getoutput(f"drbdadm primary --force {RESOURCE}")

    # Check again
    if drbd_role() != "Primary":
        return False  # promotion failed

    # Mount FS if needed
    if subprocess.call(["mountpoint", "-q", MOUNT_POINT]) != 0:
        os.system(f"mount {DRBD_DEVICE} {MOUNT_POINT}")

    return True


@app.get("/health")
def health():
    """
    Health check endpoint used by OCI Load Balancer.
    Returns 200 only if node is Primary (or successfully promoted).
    """
    if drbd_role() == "Primary":
        return {"status": "OK", "role": "Primary"}
    else:
        # Secondary returns 503 → LB will NOT send traffic here
        return Response(status_code=503)


@app.get("/", response_class=HTMLResponse)
def index():
    """
    Main endpoint:
    - If Primary: show content of /resilient
    - If Secondary: auto-promote, then show content
    """

    # Ensure we are Primary (trigger promote on failover)
    if not promote_if_needed():
        return Response("Could not promote DRBD to Primary", status_code=503)

    # Now guaranteed Primary → list directory
    try:
        path = Path(MOUNT_POINT)
        files = "<br>".join(f"- {p.name}" for p in path.iterdir())
    except Exception as e:
        files = f"<i>Error reading files: {e}</i>"

    hostname = subprocess.getoutput("hostname")
    role = drbd_role()

    html = f"""
    <html>
    <body>
        <h1>DRBD Demo Web Server</h1>
        <p><b>Hostname:</b> {hostname}</p>
        <p><b>DRBD Role:</b> {role}</p>
        <h2>Files in {MOUNT_POINT}/</h2>
        <pre>{files}</pre>
    </body>
    </html>
    """

    return HTMLResponse(content=html)


@app.get("/write/{filename}")
def write_file(filename: str):
    """Utility endpoint to create a file on the DRBD filesystem."""
    if not promote_if_needed():
        return Response("Could not promote DRBD to Primary", status_code=503)

    full_path = Path(MOUNT_POINT) / filename
    try:
        with open(full_path, "w") as f:
            f.write(f"Created on {subprocess.getoutput('hostname')}\n")
        return {"status": "OK", "file": str(full_path)}
    except Exception as e:
        return {"error": str(e)}

