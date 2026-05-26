from flask import Flask, jsonify
import docker
import socket
import subprocess
import time

app = Flask(__name__)
client = docker.from_env()

# ── Service definitions: what each container exposes on the internal network ──
SERVICES = {
    "nginx":     {"port": 443,  "proto": "tcp",  "role": "Reverse Proxy / SSL"},
    "wordpress": {"port": 9000, "proto": "tcp",  "role": "PHP-FPM Application"},
    "mariadb":   {"port": 3306, "proto": "tcp",  "role": "Database"},
    "redis":     {"port": 6379, "proto": "tcp",  "role": "Cache"},
    "adminer":   {"port": 8080, "proto": "tcp",  "role": "DB Management UI"},
    "ftp":       {"port": 21,   "proto": "tcp",  "role": "File Transfer"},
}

# ── Which containers should be able to reach which ──
CONNECTIVITY_MAP = {
    "nginx":     [("wordpress", 9000)],
    "wordpress": [("mariadb", 3306), ("redis", 6379), ("ftp", 21)],
    "adminer":   [("mariadb", 3306)],
    "ftp":       [],
    "redis":     [],
    "mariadb":   [],
    "monitor":   [("nginx", 443), ("wordpress", 9000), ("mariadb", 3306),
                  ("redis", 6379)],
}


def tcp_check(host, port, timeout=3):
    """Try to open a TCP connection. Returns (ok, latency_ms, error)."""
    start = time.time()
    try:
        s = socket.create_connection((host, port), timeout=timeout)
        s.close()
        ms = round((time.time() - start) * 1000, 1)
        return True, ms, None
    except Exception as e:
        ms = round((time.time() - start) * 1000, 1)
        return False, ms, str(e)


def dns_check(hostname):
    """Verify container DNS resolution inside the Docker network."""
    try:
        ip = socket.gethostbyname(hostname)
        return True, ip, None
    except Exception as e:
        return False, None, str(e)


# ── 1) Container status (basic list) ──
@app.route("/status")
def status():
    containers = client.containers.list(all=True)
    result = []
    for c in containers:
        info = {
            "name": c.name,
            "status": c.status,
            "image": c.image.tags,
            "running": c.status == "running",
        }
        # Add role if known
        if c.name in SERVICES:
            info["role"] = SERVICES[c.name]["role"]
        result.append(info)
    return jsonify(result)


# ── 2) Health checks: test each service's actual port ──
@app.route("/health")
def health():
    results = []
    for name, svc in SERVICES.items():
        dns_ok, ip, dns_err = dns_check(name)
        if dns_ok:
            port_ok, latency, port_err = tcp_check(name, svc["port"])
        else:
            port_ok, latency, port_err = False, 0, "DNS failed"

        results.append({
            "service": name,
            "role": svc["role"],
            "port": svc["port"],
            "dns_ok": dns_ok,
            "ip": ip,
            "port_ok": port_ok,
            "latency_ms": latency,
            "error": dns_err or port_err,
            "healthy": dns_ok and port_ok,
        })
    return jsonify(results)


# ── 3) Connectivity map: test inter-container reachability ──
@app.route("/connectivity")
def connectivity():
    results = []
    for source, targets in CONNECTIVITY_MAP.items():
        for target_name, target_port in targets:
            ok, latency, err = tcp_check(target_name, target_port)
            results.append({
                "from": source,
                "to": target_name,
                "port": target_port,
                "reachable": ok,
                "latency_ms": latency,
                "error": err,
            })
    return jsonify(results)


# ── 4) Full diagnostic: everything in one call ──
@app.route("/diagnostic")
def diagnostic():
    # Container statuses
    containers = client.containers.list(all=True)
    container_status = []
    for c in containers:
        container_status.append({
            "name": c.name,
            "status": c.status,
            "running": c.status == "running",
        })

    # Health
    health_results = []
    for name, svc in SERVICES.items():
        dns_ok, ip, dns_err = dns_check(name)
        port_ok, latency, port_err = (False, 0, "DNS failed")
        if dns_ok:
            port_ok, latency, port_err = tcp_check(name, svc["port"])
        health_results.append({
            "service": name,
            "port": svc["port"],
            "healthy": dns_ok and port_ok,
            "error": dns_err or port_err,
            "latency_ms": latency,
        })

    # Connectivity
    conn_results = []
    for source, targets in CONNECTIVITY_MAP.items():
        for target_name, target_port in targets:
            ok, latency, err = tcp_check(target_name, target_port)
            conn_results.append({
                "from": source,
                "to": target_name,
                "port": target_port,
                "reachable": ok,
                "error": err,
            })

    # Failures summary
    failures = []
    for h in health_results:
        if not h["healthy"]:
            failures.append({
                "type": "health",
                "where": f"{h['service']}:{h['port']}",
                "error": h["error"],
            })
    for c in conn_results:
        if not c["reachable"]:
            failures.append({
                "type": "connectivity",
                "where": f"{c['from']} → {c['to']}:{c['port']}",
                "error": c["error"],
            })

    return jsonify({
        "containers": container_status,
        "health": health_results,
        "connectivity": conn_results,
        "failures": failures,
        "all_ok": len(failures) == 0,
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
