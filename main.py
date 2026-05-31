import os

from flask import Flask, abort, send_from_directory

app = Flask(__name__, static_folder="build/web", static_url_path="")

@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def serve(path: str):
    file_path = os.path.join(app.static_folder, path)
    if path and os.path.exists(file_path):
        return send_from_directory(app.static_folder, path)

    index_path = os.path.join(app.static_folder, "index.html")
    if os.path.exists(index_path):
        return send_from_directory(app.static_folder, "index.html")

    abort(404)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
