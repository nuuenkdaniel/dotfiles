pragma Singleton
import QtCore
import Quickshell

// Path declarations only. Consumers create their own required directories;
// importing the media controls must never delete caches or initialize unrelated features.
Singleton {
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0]
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]
    readonly property string coverArt: FileUtils.trimFileProtocol(cache + "/media/coverart")
    // Retain the existing player/theme preference location for compatibility.
    readonly property string shellConfig: FileUtils.trimFileProtocol(config + "/illogical-impulse")
    readonly property string shellConfigPath: shellConfig + "/config.json"
}
