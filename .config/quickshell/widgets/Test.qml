import QtQuick
import QtQuick.Shapes
// import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: dashboardWindow
    visible: false

    anchors {
        top: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    // 1. Define your widget's actual visible size
    property int widgetWidth: 600
    property int widgetHeight: 400
    property int cornerRadius: 35
    
    // 2. Define your shadow properties
    property int shadowRadius: 20
    property int shadowOffset: 5

    // 3. Size the Wayland window to fit the widget PLUS the shadow padding
    // We don't pad the top because we want the widget flush with the screen edge
    implicitWidth: widgetWidth + (shadowRadius * 2)
    implicitHeight: widgetHeight + shadowRadius + shadowOffset

    Item {
        id: slideContainer
        width: parent.width
        height: parent.height

        // --- The actual visible widget bounds ---
        Item {
            id: mainWidgetArea
            width: dashboardWindow.widgetWidth
            height: dashboardWindow.widgetHeight
            
            // Keep it pushed flush against the top edge, and centered horizontally
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            Shape {
                id: customBackground
                anchors.fill: parent
                
                layer.enabled: true
                layer.samples: 4
                
                // 4. Apply the DropShadow directly to the Shape's rendering layer
                // layer.effect: DropShadow {
                //     transparentBorder: true
                //     color: Qt.rgba(0, 0, 0, 0.5) // Semi-transparent black
                //     radius: dashboardWindow.shadowRadius
                //     samples: dashboardWindow.shadowRadius * 2 + 1 // Rule of thumb: samples should be radius * 2 + 1
                //     verticalOffset: dashboardWindow.shadowOffset
                //     horizontalOffset: 0
                // }
                layer.effect: MultiEffect {
                  shadowEnabled: true
                  shadowColor: Qt.rgba(0, 0, 0, 0.75)

                  // MultiEffect uses a 0.0 to 1.0 scale for blur intensity
                  // 1.0 is the maximum, which gives that deep, soft look you want!
                  shadowBlur: 1.0 

                  shadowHorizontalOffset: dashboardWindow.shadowXOffset
                  shadowVerticalOffset: dashboardWindow.shadowYOffset
                }

                ShapePath {
                  fillColor: "#1e1e2e"
                  strokeColor: "transparent" // Ensure border is off

                  PathSvg {
                    path: {
                      // Back to the clean math without border offsets!
                      let r = dashboardWindow.cornerRadius;
                      let w = mainWidgetArea.width;
                      let h = mainWidgetArea.height;

                      return "M 0 0 " +                                                        // Start off-screen
                      "L 0 0 " +
                      "A " + r + " " + r + " 0 0 1 " + r + " " + r + " " +                // Top-Left Inverted
                      "L " + r + " " + (h - r) + " " +                                    // Left Edge
                      "A " + r + " " + r + " 0 0 0 " + (2 * r) + " " + h + " " +          // Bottom-Left Normal
                      "L " + (w - 2 * r) + " " + h + " " +                                // Bottom Edge
                      "A " + r + " " + r + " 0 0 0 " + (w - r) + " " + (h - r) + " " +    // Bottom-Right Normal
                      "L " + (w - r) + " " + r + " " +                                    // Right Edge
                      "A " + r + " " + r + " 0 0 1 " + w + " 0 " +                        // Top-Right Inverted
                      "L " + w + " -10 " +                                                // End off-screen
                      "Z";
                    }
                  }
                }
              }

              // --- YOUR WIDGET CONTENT GOES HERE ---
              Item {
                anchors.fill: parent
                anchors.leftMargin: dashboardWindow.cornerRadius
                anchors.rightMargin: dashboardWindow.cornerRadius
                anchors.topMargin: dashboardWindow.cornerRadius + 10
                anchors.bottomMargin: dashboardWindow.cornerRadius

                Text {
                  anchors.top: parent.top
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Dashboard"
                  font.pixelSize: 16
                  font.bold: true
                  color: "#ffffff" // Changed to white to match your dark theme
                }

                Row {
                  anchors.centerIn: parent
                  spacing: 20

                  Rectangle {
                    width: 150; height: 150; radius: 15
                    color: "#ffffff"; opacity: 0.1
                    Text { anchors.centerIn: parent; text: "Weather"; color: "white" }
                  }
                  Rectangle {
                    width: 150; height: 150; radius: 15
                    color: "#ffffff"; opacity: 0.1
                    Text { anchors.centerIn: parent; text: "Media"; color: "white" }
                  }
                }
              }
            }
          }
        }
