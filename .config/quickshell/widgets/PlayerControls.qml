pragma ComponentBehavior: Bound
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../components"

Item {
  id: root

  property bool visibleState: false
  property int presentedWindows: 0
  readonly property bool presentationActive: visibleState || presentedWindows > 0
  onPresentationActiveChanged: if (presentationActive) Qt.callLater(root.startArtwork)

  IpcHandler {
    target: "player"
    function toggle(): void {
      root.visibleState = !root.visibleState
    }
  }

  property MprisPlayer player: MprisController.activePlayer
  property var artUrl: player?.trackArtUrl || ""
  property string artDownloadLocation: (Directories.coverArt || "")
  property string artFilePath: `${artDownloadLocation}/${artFileName}`
  property string artFileName: Qt.md5(artUrl || "")
  property color artDominantColor: root.displayedArtFilePath
    ? ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8)
    : "#cba6f7"
  property bool downloaded: false
  property bool artworkPending: false
  property list<real> visualizerPoints: []
  property real maxVisualizerValue: 1000 // Max value in the data points
  property int visualizerSmoothing: 2 // Number of points to average for smoothing
  property real radius: 15
  property real displayPosition: 0
  property real positionOffset: 0
  property string lastTrack: ""
  property bool isLocalArt: (root.artUrl || "").startsWith("file://") || (root.artUrl || "").startsWith("/")
  property bool isDataUri: (root.artUrl || "").startsWith("data:")
  property string displayedArtFilePath: {
    if (!root.presentationActive) return "";
    if (!root.artUrl || root.artUrl === "") {
      return "";
    }
    if (root.isLocalArt || root.isDataUri) {
      return root.artUrl;
    }
    return root.downloaded ? `file://${root.artFilePath}` : "";
  }

  component TrackChangeButton: RippleButton {
    implicitWidth: 24
    implicitHeight: 24

    property var iconName
    colBackground: ColorUtils.transparentize(root.blendedColors.colSecondaryContainer, 1)
    colBackgroundHover: root.blendedColors.colSecondaryContainerHover
    colRipple: root.blendedColors.colSecondaryContainerActive

    contentItem: MaterialSymbol {
      iconSize: Appearance.font.pixelSize.huge
      fill: 1
      horizontalAlignment: Text.AlignHCenter
      color: root.blendedColors.colOnSecondaryContainer
      text: parent.iconName

      Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
      }
    }
  }

  Timer {
    running: root.presentationActive && (root.player?.playbackState === MprisPlaybackState.Playing)
    interval: 200
    repeat: true
    onTriggered: {
      root.player.positionChanged()
    }
  }

  onArtFilePathChanged: refreshArtwork()
  Component.onCompleted: refreshArtwork()

  function refreshArtwork() {
    root.downloaded = false
    root.artworkPending = true
    // Do not replace an in-flight request's identity before its exit handler.
    if (coverArtDownloader.running) coverArtDownloader.running = false
    else Qt.callLater(root.startArtwork)
  }

  function startArtwork() {
    if (!root.presentationActive || coverArtDownloader.running || !root.artworkPending) return
    root.artworkPending = false
    if (!root.artUrl || root.isLocalArt || root.isDataUri) return
    coverArtDownloader.targetFile = root.artUrl
    coverArtDownloader.artFilePath = root.artFilePath
    coverArtDownloader.command = ["python3", decodeURIComponent(Qt.resolvedUrl("../bin/artwork.py").toString().replace("file://", "")), root.artUrl, root.artFilePath]
    coverArtDownloader.running = true
  }

  function finishArtwork(exitCode) {
    root.downloaded = exitCode === 0 && !root.artworkPending
      && root.artUrl === coverArtDownloader.targetFile
      && root.artFilePath === coverArtDownloader.artFilePath
    Qt.callLater(root.startArtwork)
  }

  Process {
    id: coverArtDownloader
    property string targetFile: ""
    property string artFilePath: ""
    onExited: (exitCode, exitStatus) => root.finishArtwork(exitCode)
  }

  ColorQuantizer {
    id: colorQuantizer
    source: root.displayedArtFilePath
    // source: blurredArt.status === Image.Ready ? root.displayedArtFilePath : ""
    depth: 0 // 2^0 = 1 color
    rescaleSize: 1 // Rescale to 1x1 pixel for faster processing
  }

  property QtObject blendedColors: AdaptedMaterialScheme {
    color: root.artDominantColor
  }

  Variants {
    model: Quickshell.screens
    delegate: Component {
      PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        QtObject {
          id: animState
          property real progress: root.visibleState ? 1.0 : 0.0
          Behavior on progress {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
          }
        }
        visible: root.visibleState || animState.progress > 0
        property bool countedVisible: false
        function syncPresentation() {
          if (countedVisible === visible) return
          root.presentedWindows += visible ? 1 : -1
          countedVisible = visible
        }
        onVisibleChanged: syncPresentation()
        Component.onCompleted: syncPresentation()
        Component.onDestruction: if (countedVisible) root.presentedWindows -= 1

        anchors.top: true
        margins.top: -180 + (192 * animState.progress) 

        implicitWidth: 520 + 40
        implicitHeight: 180 + 40

        Rectangle {
          id: shadowCaster
          anchors.fill: background 
          radius: root.radius
          color: "black" 

          layer.enabled: true
          layer.effect: MultiEffect {
              shadowEnabled: true
              shadowColor: Qt.rgba(0, 0, 0, 0.75)
              shadowBlur: 1.0 
              shadowHorizontalOffset: 0
              shadowVerticalOffset: 0
          }
        }

        Rectangle {
          id: background
          anchors.fill: parent
          anchors.margins: 20
          color: root.player ? ColorUtils.applyAlpha(root.blendedColors.colLayer0, 1) : "#1e1e2e"
          border.width: root.player ? 0 : 1
          border.color: "#6b587f"
          radius: root.radius

          layer.enabled: true
          layer.effect: OpacityMask {
            maskSource: Rectangle {
              implicitWidth: background.width
              implicitHeight: background.height
              radius: background.radius
            }
          }

          Image {
            id: blurredArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            sourceSize.width: background.width
            sourceSize.height: background.height
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true

            layer.enabled: true
            layer.effect: StyledBlurEffect {
              source: blurredArt
            }

            Rectangle {
              anchors.fill: parent
              color: ColorUtils.transparentize(root.blendedColors.colLayer0, 0.3)
              radius: root.radius
            }
          }

          // WaveVisualizer {
          //   id: visualizerCanvas
          //   anchors.fill: parent
          //   live: root.player?.isPlaying ?? false
          //   points: root.visualizerPoints
          //   maxVisualizerValue: root.maxVisualizerValue
          //   smoothing: root.visualizerSmoothing
          //   color: blendedColors.colPrimary
          // }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 15

            Rectangle { // Art background
              id: artBackground
              Layout.fillHeight: true
              implicitWidth: height
              radius: Appearance.rounding.verysmall
            color: root.displayedArtFilePath ? ColorUtils.transparentize(root.blendedColors.colLayer1, 0.5) : "#313244"

              layer.enabled: true
              layer.effect: OpacityMask {
                maskSource: Rectangle {
                  implicitWidth: artBackground.width
                  implicitHeight: artBackground.height
                  radius: artBackground.radius
                }
              }

            MaterialSymbol {
              anchors.centerIn: parent
              visible: mediaArt.status !== Image.Ready
              text: "music_note"
              iconSize: 56
              color: "#cba6f7"
              fill: 1
            }

            StyledImage { // Art image
                id: mediaArt
                property int size: parent.height
                anchors.fill: parent

                source: root.displayedArtFilePath
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true

                width: size
                height: size
              }
            }

            ColumnLayout { // Info & controls
              Layout.fillHeight: true
              spacing: 2

              StyledText {
                id: trackTitle
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.large
                color: root.player ? root.blendedColors.colOnLayer0 : "#cdd6f4"
                elide: Text.ElideRight
                text: root.player ? StringUtils.cleanMusicTitle(root.player.trackTitle) || "Untitled" : "Nothing playing"
                animateChange: true
                animationDistanceX: 6
                animationDistanceY: 0
              }
              StyledText {
                id: trackArtist
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.player ? root.blendedColors.colSubtext : "#bac2de"
                elide: Text.ElideRight
                text: root.player ? root.player.trackArtist || root.player.identity : "Start some music to see it here"
                // text: root.player?.trackArtist
                animateChange: true
                animationDistanceX: 6
                animationDistanceY: 0
              }
              Item { Layout.fillHeight: true }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0 // Adds a clean gap between the buttons and the progress bar

                // 1. TOP ROW: Time on Left, Controls on Right
                Item {
                  Layout.fillWidth: true
                  // Automatically sizes to whichever is taller: the text or the big buttons
                  implicitHeight: Math.max(trackTime.implicitHeight, mediaControlsRow.implicitHeight)

                  StyledText {
                    id: trackTime
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
                    visible: !!root.player && root.player.length > 0
                  }

                  Row {
                    id: mediaControlsRow
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 12

                    TrackChangeButton {
                      anchors.verticalCenter: parent.verticalCenter
                      iconName: "skip_previous"
                      enabled: root.player?.canGoPrevious ?? false
                      opacity: enabled ? 1 : .35
                      downAction: () => root.player?.previous()
                    }

                    RippleButton {
                      id: playPauseButton
                      anchors.verticalCenter: parent.verticalCenter
                      
                      property real size: 44
                      
                      implicitWidth: size
                      implicitHeight: size
                      enabled: root.player?.canTogglePlaying ?? false
                      opacity: enabled ? 1 : .45
                      downAction: () => root.player?.togglePlaying();

                      buttonRadius: root.player?.isPlaying ? Appearance?.rounding.normal : size / 2
                      colBackground: root.player?.isPlaying ? root.blendedColors.colPrimary : root.blendedColors.colSecondaryContainer
                      colBackgroundHover: root.player?.isPlaying ? root.blendedColors.colPrimaryHover : root.blendedColors.colSecondaryContainerHover
                      colRipple: root.player?.isPlaying ? root.blendedColors.colPrimaryActive : root.blendedColors.colSecondaryContainerActive

                      contentItem: MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.huge
                        fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.player?.isPlaying ? root.blendedColors.colOnPrimary : root.blendedColors.colOnSecondaryContainer
                        text: root.player?.isPlaying ? "pause" : "play_arrow"

                        Behavior on color {
                          animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                      }
                    }

                    TrackChangeButton {
                      anchors.verticalCenter: parent.verticalCenter
                      iconName: "skip_next"
                      enabled: root.player?.canGoNext ?? false
                      opacity: enabled ? 1 : .35
                      downAction: () => root.player?.next()
                    }
                  }
                }

                // 2. BOTTOM ROW: The Progress Bar
                Item {
                  id: progressBarContainer
                  visible: !!root.player && root.player.length > 0
                  Layout.fillWidth: true
                  implicitHeight: Math.max(sliderLoader.implicitHeight, progressBarLoader.implicitHeight)

                  Loader {
                    id: sliderLoader
                    anchors.fill: parent
                    active: root.player?.canSeek ?? false
                    sourceComponent: StyledSlider { 
                      configuration: StyledSlider.Configuration.Wavy
                      animateWave: root.presentationActive && !!root.player?.isPlaying
                      highlightColor: root.blendedColors.colPrimary
                      trackColor: root.blendedColors.colSecondaryContainer
                      handleColor: root.blendedColors.colPrimary
                      value: root.player?.length > 0 ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
                      onMoved: {
                        root.player.position = value * root.player.length;
                      }
                    }
                  }

                  Loader {
                    id: progressBarLoader
                    anchors {
                      verticalCenter: parent.verticalCenter
                      left: parent.left
                      right: parent.right
                    }
                    active: !(root.player?.canSeek ?? false)
                    sourceComponent: StyledProgressBar { 
                      wavy: root.player?.isPlaying ?? false
                      animateWave: root.presentationActive && !!root.player?.isPlaying
                      highlightColor: root.blendedColors.colPrimary
                      trackColor: root.blendedColors.colSecondaryContainer
                      value: root.player?.length > 0 ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
