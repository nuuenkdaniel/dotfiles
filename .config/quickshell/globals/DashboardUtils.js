.pragma library

function cpuUsage(previous, current) {
    if (!previous || !current) return -1;
    const delta = current.total - previous.total;
    if (delta <= 0 || current.idle < previous.idle) return -1;
    return Math.max(0, Math.min(1, 1 - (current.idle - previous.idle) / delta));
}

function bytes(value) {
    if (!Number.isFinite(value)) return "—";
    const unit = value >= 1073741824 ? " GiB" : " MiB";
    return (value / (value >= 1073741824 ? 1073741824 : 1048576)).toFixed(1) + unit;
}

function calendar(year, month) {
    const first = new Date(year, month, 1, 12);
    const offset = (first.getDay() + 6) % 7;
    return Array.from({length: 42}, (_, index) => {
        const date = new Date(year, month, index - offset + 1, 12);
        return {day: date.getDate(), month: date.getMonth(), year: date.getFullYear()};
    });
}

function weather(code, day) {
    if (code === 0) return [day ? "sunny" : "clear_night", "Clear"];
    if (code <= 2) return ["partly_cloudy_day", "Partly cloudy"];
    if (code === 3) return ["cloud", "Overcast"];
    if ([45, 48].includes(code)) return ["foggy", "Fog"];
    if (code >= 95) return ["thunderstorm", "Thunderstorms"];
    if ([71, 73, 75, 77, 85, 86].includes(code)) return ["weather_snowy", "Snow"];
    if (code >= 51 && code <= 82) return ["rainy", "Rain"];
    return ["cloud", "Weather"];
}
