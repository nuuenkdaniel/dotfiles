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

  IpcHandler {
    target: "player"
    function toggle(): void {
      root.visibleState = !root.visibleState
    }
  }

  Connections {
    target: MprisController
    function onActivePlayerChanged() {
      if (MprisController.activePlayer !== null) {
        root.player = MprisController.activePlayer;
      }
    }
  }
  property MprisPlayer player: MprisController.activePlayer
  property var artUrl: player?.trackArtUrl || ""
  property string artDownloadLocation: (Directories.coverArt || "")
  property string artFilePath: `${artDownloadLocation}/${artFileName}`
  property string artFileName: Qt.md5(artUrl || "")
  property color artDominantColor: ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
  property bool downloaded: false
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
    colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
    colBackgroundHover: blendedColors.colSecondaryContainerHover
    colRipple: blendedColors.colSecondaryContainerActive

    contentItem: MaterialSymbol {
      iconSize: Appearance.font.pixelSize.huge
      fill: 1
      horizontalAlignment: Text.AlignHCenter
      color: blendedColors.colOnSecondaryContainer
      text: iconName

      Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
      }
    }
  }

  Timer {
    running: (root.player?.playbackState === MprisPlaybackState.Playing) || false
    interval: 200
    repeat: true
    onTriggered: {
      root.player.positionChanged()
    }
  }

  onArtFilePathChanged: {
    if ((root.artUrl || "").length === 0) {
      root.artDominantColor = Appearance.m3colors.m3secondaryContainer
      return;
    }

    if (root.isLocalArt || root.isDataUri) {
      return;
    }
    coverArtDownloader.running = false

    coverArtDownloader.targetFile = root.artUrl 
    coverArtDownloader.artFilePath = root.artFilePath
    root.downloaded = false
    coverArtDownloader.running = true
  }

  Process {
    id: coverArtDownloader
    property string targetFile: root.artUrl
    property string artFilePath: root.artFilePath
    command: [ "bash", "-c", `[ -f '${artFilePath}' ] || curl -sSL '${targetFile}' -o '${artFilePath}'` ]
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0 && root.artFilePath === artFilePath) {
        root.downloaded = true
      }
    }
  }

  ColorQuantizer {
    id: colorQuantizer
    source: root.displayedArtFilePath
    // source: blurredArt.status === Image.Ready ? root.displayedArtFilePath : ""
    depth: 0 // 2^0 = 1 color
    rescaleSize: 1 // Rescale to 1x1 pixel for faster processing
  }

  property QtObject blendedColors: AdaptedMaterialScheme {
    color: artDominantColor
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
              shadowColor: Qt.rgba(0, 0, 0, 0.6)
              shadowBlur: 0.8 
              shadowHorizontalOffset: 5 
              shadowVerticalOffset: 5
          }
        }

        Rectangle {
          id: background
          anchors.fill: parent
          anchors.margins: 20
          color: ColorUtils.applyAlpha(blendedColors.colLayer0, 1)
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
              color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
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
              color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

              layer.enabled: true
              layer.effect: OpacityMask {
                maskSource: Rectangle {
                  implicitWidth: artBackground.width
                  implicitHeight: artBackground.height
                  radius: artBackground.radius
                }
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
                color: blendedColors.colOnLayer0
                elide: Text.ElideRight
                text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "Untitled"
                animateChange: true
                animationDistanceX: 6
                animationDistanceY: 0
              }
              StyledText {
                id: trackArtist
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: blendedColors.colSubtext
                elide: Text.ElideRight
                text: root.player?.trackArtist || ""
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
                    color: blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
                  }

                  Row {
                    id: mediaControlsRow
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 12

                    TrackChangeButton {
                      anchors.verticalCenter: parent.verticalCenter
                      iconName: "skip_previous"
                      downAction: () => root.player?.previous()
                    }

                    RippleButton {
                      id: playPauseButton
                      anchors.verticalCenter: parent.verticalCenter
                      
                      property real size: 44
                      
                      implicitWidth: size
                      implicitHeight: size
                      downAction: () => root.player.togglePlaying();

                      buttonRadius: root.player?.isPlaying ? Appearance?.rounding.normal : size / 2
                      colBackground: root.player?.isPlaying ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                      colBackgroundHover: root.player?.isPlaying ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover
                      colRipple: root.player?.isPlaying ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive

                      contentItem: MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.huge
                        fill: 1
                        horizontalAlignment: Text.AlignHCenter
                        color: root.player?.isPlaying ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                        text: root.player?.isPlaying ? "pause" : "play_arrow"

                        Behavior on color {
                          animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                      }
                    }

                    TrackChangeButton {
                      anchors.verticalCenter: parent.verticalCenter
                      iconName: "skip_next"
                      downAction: () => root.player?.next()
                    }
                  }
                }

                // 2. BOTTOM ROW: The Progress Bar
                Item {
                  id: progressBarContainer
                  Layout.fillWidth: true
                  implicitHeight: Math.max(sliderLoader.implicitHeight, progressBarLoader.implicitHeight)

                  Loader {
                    id: sliderLoader
                    anchors.fill: parent
                    active: root.player?.canSeek ?? false
                    sourceComponent: StyledSlider { 
                      configuration: StyledSlider.Configuration.Wavy
                      highlightColor: blendedColors.colPrimary
                      trackColor: blendedColors.colSecondaryContainer
                      handleColor: blendedColors.colPrimary
                      value: root.player?.position / root.player?.length
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
                      highlightColor: blendedColors.colPrimary
                      trackColor: blendedColors.colSecondaryContainer
                      value: root.player?.position / root.player?.length
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
