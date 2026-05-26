// ── Helper: color based on status ──
function badge(ok) {
    return ok
        ? '<span style="color:#22c55e">✅ OK</span>'
        : '<span style="color:#ef4444">❌ FAIL</span>';
}

// ── 1) Container Status ──
async function loadStatus() {
    try {
        const res = await fetch("/api/status");
        const data = await res.json();
        let html = '<table><tr><th>Container</th><th>Role</th><th>Status</th><th>Image</th></tr>';
        data.forEach(c => {
            const color = c.running ? '#22c55e' : '#ef4444';
            html += `<tr>
                <td>${c.name}</td>
                <td>${c.role || '—'}</td>
                <td style="color:${color}">${c.status}</td>
                <td>${c.image}</td>
            </tr>`;
        });
        html += '</table>';
        document.getElementById('status').innerHTML = html;
    } catch (err) {
        document.getElementById('status').innerHTML = '<p style="color:red">Monitor API not reachable</p>';
    }
}

// ── 2) Health Checks ──
async function loadHealth() {
    try {
        const res = await fetch("/api/health");
        const data = await res.json();
        let html = '<table><tr><th>Service</th><th>Port</th><th>DNS</th><th>Port Open</th><th>Latency</th><th>Error</th></tr>';
        data.forEach(h => {
            html += `<tr>
                <td>${h.service}</td>
                <td>${h.port}</td>
                <td>${badge(h.dns_ok)}</td>
                <td>${badge(h.port_ok)}</td>
                <td>${h.latency_ms} ms</td>
                <td style="color:#f59e0b">${h.error || '—'}</td>
            </tr>`;
        });
        html += '</table>';
        document.getElementById('health').innerHTML = html;
    } catch (err) {
        document.getElementById('health').innerHTML = '<p style="color:red">Could not load health data</p>';
    }
}

// ── 3) Connectivity Map ──
async function loadConnectivity() {
    try {
        const res = await fetch("/api/connectivity");
        const data = await res.json();
        let html = '<table><tr><th>From</th><th>→</th><th>To</th><th>Port</th><th>Reachable</th><th>Latency</th><th>Error</th></tr>';
        data.forEach(c => {
            html += `<tr>
                <td>${c.from}</td>
                <td>→</td>
                <td>${c.to}</td>
                <td>${c.port}</td>
                <td>${badge(c.reachable)}</td>
                <td>${c.latency_ms} ms</td>
                <td style="color:#f59e0b">${c.error || '—'}</td>
            </tr>`;
        });
        html += '</table>';
        document.getElementById('connectivity').innerHTML = html;
    } catch (err) {
        document.getElementById('connectivity').innerHTML = '<p style="color:red">Could not load connectivity data</p>';
    }
}

// ── 4) Failure Report ──
async function loadFailures() {
    try {
        const res = await fetch("/api/diagnostic");
        const data = await res.json();
        if (data.all_ok) {
            document.getElementById('failures').innerHTML =
                '<p style="color:#22c55e; font-size:1.2em">✅ All systems operational — no failures detected</p>';
            return;
        }
        let html = '<table><tr><th>Type</th><th>Where</th><th>Error</th></tr>';
        data.failures.forEach(f => {
            html += `<tr style="color:#ef4444">
                <td>${f.type.toUpperCase()}</td>
                <td>${f.where}</td>
                <td>${f.error}</td>
            </tr>`;
        });
        html += '</table>';
        document.getElementById('failures').innerHTML = html;
    } catch (err) {
        document.getElementById('failures').innerHTML = '<p style="color:red">Could not load diagnostic</p>';
    }
}

// ── Load everything and auto-refresh every 5s ──
function loadAll() {
    loadStatus();
    loadHealth();
    loadConnectivity();
    loadFailures();
}

loadAll();
setInterval(loadAll, 5000);
