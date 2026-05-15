from flask import Flask, jsonify
import docker

app = Flask(__name__)
client = docker.from_env()

@app.route("/status")
def status():
    containers = client.containers.list(all=True)

    result = []
    for c in containers:
        result.append({
            "name": c.name,
            "status": c.status,
            "image": c.image.tags
        })

    return jsonify(result)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)