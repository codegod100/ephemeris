"""Deploy the Helios Sky web app to Modal.

    pip install modal && modal setup     # once
    modal deploy deploy/modal_app.py     # build and deploy
    modal serve deploy/modal_app.py      # temporary dev URL, redeploys on change

Flutter is installed and the web app is built inside the Modal image, so no
local Flutter SDK is needed. Modal serves over HTTPS, which browsers require
for the motion sensors, camera and GPS.
"""

from pathlib import Path

import modal

REPO = Path(__file__).resolve().parent.parent
FLUTTER = "/opt/flutter"
SRC = "/src"
WEB_ROOT = f"{SRC}/build/web"

image = (
    modal.Image.debian_slim(python_version="3.12")
    .apt_install("git", "curl", "unzip", "xz-utils", "ca-certificates")
    .run_commands(
        f"git clone --depth 1 -b stable https://github.com/flutter/flutter.git {FLUTTER}",
        f"{FLUTTER}/bin/flutter config --no-analytics --enable-web",
        f"{FLUTTER}/bin/flutter precache --web",
    )
    .env({"PATH": f"{FLUTTER}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"})
    .pip_install("fastapi[standard]")
    # Source goes in last so edits don't invalidate the Flutter layers above.
    .add_local_dir(
        REPO,
        SRC,
        copy=True,
        ignore=[".git", ".dart_tool", "build", "web", "**/.DS_Store", "android", "ios", "deploy"],
    )
    .run_commands(
        # Generate the standard web/ boilerplate (not committed), then build.
        f"cd {SRC} && flutter create --org io.github.heliosky --project-name helios_sky --platforms web .",
        f"cd {SRC} && flutter pub get && flutter build web --release",
    )
)

app = modal.App("helios-sky", image=image)


@app.function()
@modal.concurrent(max_inputs=100)
@modal.asgi_app()
def web():
    from fastapi import FastAPI, Request
    from fastapi.staticfiles import StaticFiles

    api = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)

    @api.middleware("http")
    async def no_cache_entrypoints(request: Request, call_next):
        # Hashed assets can be cached; the entry points must not be, or
        # browsers keep running an old build after a redeploy.
        response = await call_next(request)
        path = request.url.path
        if path in ("/", "/index.html", "/flutter_bootstrap.js", "/flutter_service_worker.js", "/version.json"):
            response.headers["Cache-Control"] = "no-cache"
        return response

    api.mount("/", StaticFiles(directory=WEB_ROOT, html=True), name="web")
    return api
