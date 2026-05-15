async function loadStatus() {
    try {
        const res = await fetch("/api/status");
        const data = await res.json();

        let html = `
        <table>
            <tr>
                <th>Container</th>
                <th>Status</th>
                <th>Image</th>
            </tr>
        `;

        data.forEach(c => {
            html += `
                <tr>
                    <td>${c.name}</td>
                    <td>${c.status}</td>
                    <td>${c.image}</td>
                </tr>
            `;
        });

        html += "</table>";

        document.getElementById("status").innerHTML = html;

    } catch (err) {
        document.getElementById("status").innerHTML =
            "<p style='color:red'>API not reachable</p>";
    }
}

loadStatus();
setInterval(loadStatus, 5000);