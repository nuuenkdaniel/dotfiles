pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "../globals/Theme.js" as Theme

// A continuous extension of the sidebar, with transparent inverted shoulders.
// The path has no left-hand border or wallpaper-coloured corner patches.
Shape {
    id: root
    required property real panelHeight
    property real shoulder: 20
    property real rounding: 20
    property bool reachesBottom: false
    readonly property real r: Math.min(rounding, panelHeight / 2, width / 2)
    readonly property real bottomRadius: reachesBottom ? 0 : r
    height: Math.max(0, panelHeight) + 2 * shoulder
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: -1
        fillColor: Theme.background
        startX: 0; startY: 0
        PathQuad { x: root.shoulder; y: root.shoulder; controlX: 0; controlY: root.shoulder }
        PathLine { x: root.width - root.r; y: root.shoulder }
        PathArc { x: root.width; y: root.shoulder + root.r; radiusX: root.r; radiusY: root.r }
        PathLine { x: root.width; y: root.shoulder + root.panelHeight - root.bottomRadius }
        PathArc { x: root.width - root.bottomRadius; y: root.shoulder + root.panelHeight; radiusX: root.bottomRadius; radiusY: root.bottomRadius }
        PathLine { x: root.shoulder; y: root.shoulder + root.panelHeight }
        PathQuad { x: 0; y: root.height; controlX: 0; controlY: root.shoulder + root.panelHeight }
        PathLine { x: 0; y: 0 }
    }
}
