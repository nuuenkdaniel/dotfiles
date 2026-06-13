import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

PanelWindow {
    id: root

    // Anchor to the top edge, stretching across the screen
    anchors {
        top: true
        left: true
        right: true
    }
    
    // Set the height of your bar
    height: 40
    color: "transparent"
    
    // Start completely unmapped/hidden
    visible: false

    // The IPC trigger for your compositor
    IpcHandler {
        target: "sliding_bar"
        function toggle() {
            if (innerBar.state === "closed") {
                // Instantly show the transparent window wrapper
                root.visible = true 
                // Trigger the slide down animation
                innerBar.state = "open" 
            } else {
                // Trigger the slide up animation (visibility is handled in the Transition)
                innerBar.state = "closed" 
            }
        }
    }

    // The actual visible background of your bar
    Rectangle {
        id: innerBar
        width: parent.width
        height: parent.height
        color: "#1e1e2e" 
        
        // Default to the closed state
        state: "closed"

        // --- THE STATES ---
        states: [
            State {
                name: "open"
                // Flush with the top of the window
                PropertyChanges { target: innerBar; y: 0 } 
            },
            State {
                name: "closed"
                // Moved completely off-screen (negative Y)
                PropertyChanges { target: innerBar; y: -innerBar.height } 
            }
        ]

        // --- THE ANIMATIONS ---
        transitions: [
            // Animation for Sliding In
            Transition {
                from: "closed"; to: "open"
                NumberAnimation { 
                    target: innerBar
                    property: "y"
                    duration: 350 
                    easing.type: Easing.OutExpo // Fast entrance, smooth deceleration
                }
            },
            
            // Animation for Sliding Out
            Transition {
                from: "open"; to: "closed"
                SequentialAnimation {
                    NumberAnimation { 
                        target: innerBar
                        property: "y"
                        duration: 300 
                        easing.type: Easing.InExpo // Slow start, fast exit
                    }
                    // Crucial: Wait for the slide to finish, THEN hide the Wayland window
                    ScriptAction { 
                        script: root.visible = false 
                    }
                }
            }
        ]

        // --- YOUR BAR CONTENT ---
        Row {
            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "🚀 Sliding Waybar"
                color: "#cdd6f4"
                font.bold: true
                font.pixelSize: 14
            }
            
            Text {
                text: Qt.formatDateTime(new Date(), "hh:mm ap")
                color: "#a6adc8"
                font.pixelSize: 14
            }
        }
    }
}
