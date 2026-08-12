pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property real cpuPercent: 0
    property real memoryPercent: 0
    property real memoryUsedGiB: 0
    property real diskPercent: 0
    property real diskFreeGiB: 0
    property string topCpuProcesses: "Collecting process usage…"
    property string topMemoryProcesses: "Collecting process usage…"

    property real previousCpuTotal: 0
    property real previousCpuIdle: 0

    function updateCpu(): void {
        const line = cpuFile.text().split("\n")[0].trim();
        const fields = line.split(/\s+/).slice(1).map(Number);
        if (fields.length < 5 || fields.some(value => !Number.isFinite(value)))
            return;

        const total = fields.reduce((sum, value) => sum + value, 0);
        const idle = fields[3] + fields[4];
        if (previousCpuTotal > 0 && total > previousCpuTotal) {
            const totalDelta = total - previousCpuTotal;
            const idleDelta = idle - previousCpuIdle;
            cpuPercent = Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta));
        }

        previousCpuTotal = total;
        previousCpuIdle = idle;
    }

    function updateMemory(): void {
        const values = {};
        for (const line of memoryFile.text().split("\n")) {
            const match = line.match(/^(MemTotal|MemAvailable):\s+(\d+)/);
            if (match)
                values[match[1]] = Number(match[2]);
        }

        const totalKiB = values.MemTotal || 0;
        const availableKiB = values.MemAvailable || 0;
        if (totalKiB <= 0)
            return;

        const usedKiB = Math.max(0, totalKiB - availableKiB);
        memoryUsedGiB = usedKiB / 1048576;
        memoryPercent = 100 * usedKiB / totalKiB;
    }

    function updateDisk(output: string): void {
        const lines = output.trim().split("\n");
        if (lines.length < 2)
            return;

        const fields = lines[lines.length - 1].trim().split(/\s+/).map(Number);
        if (fields.length < 2 || !Number.isFinite(fields[0]) || !Number.isFinite(fields[1]) || fields[0] <= 0)
            return;

        diskFreeGiB = fields[1] / 1073741824;
        diskPercent = 100 * (fields[0] - fields[1]) / fields[0];
    }

    function updateProcesses(output: string): void {
        const totals = {};

        for (const line of output.trim().split("\n")) {
            const fields = line.trim().split(/\s+/);
            if (fields.length < 3)
                continue;

            const rssKiB = Number(fields.pop());
            const cpu = Number(fields.pop());
            const name = fields.join(" ");
            if (!name || !Number.isFinite(cpu) || !Number.isFinite(rssKiB))
                continue;

            if (totals[name] === undefined)
                totals[name] = { "name": name, "cpu": 0, "rssKiB": 0 };
            totals[name].cpu += cpu;
            totals[name].rssKiB += rssKiB;
        }

        const processes = Object.values(totals);
        const cpu = processes.slice().sort((a, b) => b.cpu - a.cpu).slice(0, 5);
        const memory = processes.slice().sort((a, b) => b.rssKiB - a.rssKiB).slice(0, 5);

        topCpuProcesses = cpu.length > 0
            ? cpu.map(entry => entry.name + "  " + entry.cpu.toFixed(1) + "%").join("\n")
            : "No active processes";
        topMemoryProcesses = memory.length > 0
            ? memory.map(entry => entry.name + "  " + (entry.rssKiB / 1024).toFixed(0) + " MiB").join("\n")
            : "No active processes";
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        printErrors: false
        onTextChanged: root.updateCpu()
    }

    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        printErrors: false
        onTextChanged: root.updateMemory()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: cpuFile.reload()
    }

    Process {
        id: processUsage
        command: [Runtime.psPath, "--no-headers", "-eo", "comm=,pcpu=,rss="]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.updateProcesses(text)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            if (!processUsage.running)
                processUsage.running = true;
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: memoryFile.reload()
    }

    Process {
        id: diskProcess
        command: [Runtime.dfPath, "-B1", "--output=size,avail", "/"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.updateDisk(text)
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            if (!diskProcess.running)
                diskProcess.running = true;
        }
    }
}
