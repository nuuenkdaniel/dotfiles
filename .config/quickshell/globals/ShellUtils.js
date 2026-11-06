.pragma library

function warningBand(percent) {
    if (!Number.isFinite(percent) || percent < 0 || percent > 20) return null;
    return Math.ceil(percent / 5) * 5;
}

function mergeHistory(entries, entry, limit) {
    return [entry].concat(entries.filter(item => item.key !== entry.key)).slice(0, limit);
}

function notificationSession(stat, boot) {
    const fields = stat.slice(stat.lastIndexOf(")") + 2).trim().split(/\s+/);
    const pid = stat.slice(0, stat.indexOf(" "));
    if (!/^\d+$/.test(pid) || !/^\d+$/.test(fields[19] || "") || !boot.trim())
        throw new Error("Could not identify notification session");
    return boot.trim() + ":" + pid + ":" + fields[19];
}

function mergeNotificationHistory(entries, entry, limit) {
    const snapshot = Object.assign({}, entry);
    delete snapshot.replayed;
    if (entry.replayed) {
        const previous = entries.find(item => item.key === entry.key)
            || entries.find(item => /^\d+$/.test(item.session || "") && item.id === entry.id
                && item.appName === entry.appName && item.summary === entry.summary && item.body === entry.body);
        if (previous) {
            snapshot.timestamp = previous.timestamp;
            return entries.map(item => item === previous ? snapshot : item).slice(0, limit);
        }
    }
    return mergeHistory(entries, snapshot, limit);
}

function notificationIcon(icon, lookup) {
    if (typeof icon !== "string" || !icon || /[\x00-\x1f\x7f]/.test(icon)) return "";
    if (icon.startsWith("/")) return "file://" + icon;
    if (icon.startsWith("file:///")) return icon;
    if (icon.startsWith("qrc:/") || icon.startsWith(":/")) return icon;
    return !icon.includes(":") && !icon.includes("/") ? lookup(icon) : "";
}

function cleanHistory(entries) {
    if (!entries || typeof entries.length !== "number" || typeof entries.filter !== "function") return [];
    return entries.filter(entry => entry && typeof entry.key === "string"
        && Number.isFinite(entry.timestamp) && typeof entry.summary === "string"
        && typeof entry.body === "string").slice(0, 100).map(entry => ({
            key: entry.key.slice(0, 200), timestamp: entry.timestamp,
            session: typeof entry.session === "string" ? entry.session : "",
            id: Number.isFinite(entry.id) ? entry.id : -1,
            appName: typeof entry.appName === "string" ? entry.appName.slice(0, 200) : "",
            appIcon: typeof entry.appIcon === "string" ? entry.appIcon.slice(0, 2000) : "",
            desktopEntry: typeof entry.desktopEntry === "string" ? entry.desktopEntry.slice(0, 300) : "",
            summary: entry.summary.slice(0, 500), body: entry.body.slice(0, 8000),
            critical: entry.critical === true
        }));
}

function captureEvent(counts, data) {
    const parts = data.split(",");
    if (parts.length < 3 || !["0", "1"].includes(parts[0])) return counts;
    const key = parts.slice(1).join(",");
    const next = Object.assign({}, counts);
    next[key] = Math.max(0, (next[key] || 0) + (parts[0] === "1" ? 1 : -1));
    if (!next[key]) delete next[key];
    return next;
}
