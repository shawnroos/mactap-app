// Runs inside the MacTap device via [node.script]. Starts the bridge binary
// that sits next to this file, relays its output to the device's status
// line, and stops it when the device unloads.
const Max = require("max-api");
const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");

const BIN = path.join(__dirname, "mactap-midi");
let child = null;

function status(text) {
    Max.outlet("status", text);
}

function start() {
    if (child) return;
    if (!fs.existsSync(BIN)) {
        status("mactap-midi missing next to the device — run install.sh");
        return;
    }
    // stdin stays open for the bridge's lifetime; it exits when this pipe closes.
    child = spawn(BIN, ["--osc", "127.0.0.1:7400"], { stdio: ["pipe", "pipe", "pipe"] });
    status("starting");
    child.stdout.on("data", (d) => {
        for (const line of d.toString().split("\n")) {
            if (!line) continue;
            Max.post(line);
            if (line.startsWith("hit")) continue;
            if (line.startsWith("  MIDI source")) status("running — knock");
            else if (line.includes("PARKED")) status("sensor parked");
            else if (line.startsWith("set ")) status("running — " + line.slice(4));
        }
    });
    child.stderr.on("data", (d) => {
        for (const line of d.toString().split("\n")) {
            if (!line.trim()) continue;
            Max.post("mactap-midi: " + line);
            // NSLog chatter ("... MacTap: SPU idle") is not a status; real errors have no timestamp prefix.
            if (!/^\d{4}-\d\d-\d\d /.test(line)) status(line);
        }
    });
    child.on("exit", (code) => {
        child = null;
        if (code === 3) status("another MacTap device is already running");
        else if (code) status("bridge exited (" + code + ")");
        else status("stopped");
    });
}

function stop() {
    if (!child) return;
    child.stdin.end();
    child.kill("SIGINT");
    child = null;
}

Max.addHandler("start", start);
Max.addHandler("stop", stop);
Max.addHandler("restart", () => { stop(); setTimeout(start, 500); });
process.on("exit", stop);
process.on("SIGTERM", () => { stop(); process.exit(0); });

start();
