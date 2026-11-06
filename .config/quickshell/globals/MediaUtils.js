.pragma library

function isEligible(player, filterDuplicates, hasIntegration) {
    if (!player) return false;
    if (!filterDuplicates) return true;
    const name = player.dbusName || "";
    if (name.startsWith("org.mpris.MediaPlayer2.playerctld")) return false;
    if (hasIntegration && /^(org\.mpris\.MediaPlayer2\.)(chromium|firefox|google-chrome|brave|opera|vivaldi)(\.|$)/.test(name)) return false;
    return !(name.endsWith(".mpd") && !name.endsWith("MediaPlayer2.mpd"));
}

function choosePlayer(players, tracked) {
    if (players.includes(tracked) && tracked.isPlaying) return tracked;
    return players.find(player => player.isPlaying)
        || (players.includes(tracked) ? tracked : null) || players[0] || null;
}
