pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// One continuous outline: the shoulders are negative-space curves, never
// wallpaper-coloured rectangles. The strip and body cannot develop a seam.
Shape {
    id: root
    required property real panelLeft
    required property real panelWidth
    required property real panelHeight
    property real stripHeight: 6
    property real shoulder: 28
    property real rounding: 28
    readonly property real bottomEdge: stripHeight + Math.max(0, panelHeight)
    readonly property real r: Math.min(rounding, Math.max(0, panelHeight) / 2)
    readonly property real s: Math.min(shoulder, Math.max(0, panelHeight) / 2)
    readonly property real rightEdge: panelLeft + panelWidth
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: -1
        fillColor: "#1e1e2e"
        startX: 0; startY: 0
        PathLine { x: root.width; y: 0 }
        PathLine { x: root.width; y: root.stripHeight }
        PathLine { x: root.rightEdge + root.s; y: root.stripHeight }
        PathArc { x: root.rightEdge; y: root.stripHeight + root.s; radiusX: root.s; radiusY: root.s; direction: PathArc.Counterclockwise }
        PathLine { x: root.rightEdge; y: root.bottomEdge - root.r }
        PathArc { x: root.rightEdge - root.r; y: root.bottomEdge; radiusX: root.r; radiusY: root.r }
        PathLine { x: root.panelLeft + root.r; y: root.bottomEdge }
        PathArc { x: root.panelLeft; y: root.bottomEdge - root.r; radiusX: root.r; radiusY: root.r }
        PathLine { x: root.panelLeft; y: root.stripHeight + root.s }
        PathArc { x: root.panelLeft - root.s; y: root.stripHeight; radiusX: root.s; radiusY: root.s; direction: PathArc.Counterclockwise }
        PathLine { x: 0; y: root.stripHeight }
        PathLine { x: 0; y: 0 }
    }
}
