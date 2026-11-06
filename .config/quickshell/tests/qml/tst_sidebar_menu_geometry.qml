import QtQuick
import QtTest
import "../../components"

TestCase {
    id: testCase
    name: "SidebarMenuGeometry"
    when: windowShown
    property var subject
    Component {
        id: factory
        SidebarMenuGeometry {
            targetWidth: 240
            targetHeight: 120
            anchorY: 850
            availableHeight: 900
        }
    }
    Component {
        id: contentFactory
        SidebarMenuGeometry {
            id: surface
            property var entries: [{text: "Short", triggered: function() {}}]
            targetWidth: content.item?.implicitWidth ?? 240
            targetHeight: content.item?.implicitHeight ?? 0
            anchorY: 850
            availableHeight: 900
            Loader {
                id: content
                anchors.fill: parent
                sourceComponent: PopupMenuContent {
                    menuModel: surface.entries
                    maximumWidth: 320
                    maximumHeight: 888
                }
            }
        }
    }

    function init() {
        subject = createTemporaryObject(factory, testCase)
        verify(subject !== null)
    }

    function test_first_open_snaps_to_its_final_geometry() {
        compare(subject.width, 240)
        compare(subject.height, 120)
        compare(subject.y, 780)
        compare(subject.running, false)
        subject.targetWidth = 300
        subject.targetHeight = 260
        compare(subject.width, 300)
        compare(subject.height, 260)
        compare(subject.y, 640)
        compare(subject.running, false)
    }

    function test_open_menu_morphs_width_height_and_position_together() {
        subject.animateChanges = true
        subject.targetWidth = 320
        subject.targetHeight = 300
        compare(subject.width, 240)
        compare(subject.height, 120)
        tryVerify(() => subject.running)
        wait(80)
        verify(subject.width > 240 && subject.width < 320)
        verify(subject.height > 120 && subject.height < 300)
        verify(subject.y < 780 && subject.y > 600)
        // Both old and new menus touch the bottom. There must be no gap or
        // overshoot from y repeatedly chasing the interpolated height.
        fuzzyCompare(subject.y + subject.height, 900, .5)
        tryCompare(subject, "running", false, 1000)
        compare(subject.width, 320)
        compare(subject.height, 300)
        compare(subject.y, 600)
    }

    function test_rapid_switches_retarget_without_jumping_or_reopening() {
        subject.animateChanges = true
        subject.targetHeight = 340
        wait(60)
        const currentHeight = subject.height
        subject.targetHeight = 80
        fuzzyCompare(subject.height, currentHeight, .1)
        verify(subject.running)
        tryCompare(subject, "running", false, 1000)
        compare(subject.height, 80)
        compare(subject.y, 820)
    }

    function test_close_or_monitor_change_finishes_uncompleted_morph() {
        subject.animateChanges = true
        subject.targetHeight = 300
        wait(40)
        subject.animateChanges = false
        compare(subject.running, false)
        compare(subject.height, 300)
        compare(subject.y, 600)
        subject.targetHeight = 100
        compare(subject.height, 100)
        compare(subject.y, 800)
    }

    function test_real_content_targets_are_independent_of_animated_surface_size() {
        const surface = createTemporaryObject(contentFactory, testCase)
        tryVerify(() => surface.targetHeight > 20)
        wait(30)
        compare(surface.running, false)
        const oldWidth = surface.width
        const oldHeight = surface.height
        surface.animateChanges = true
        surface.entries = [
            {text: "A very long audio device description that needs more space", triggered: function() {}},
            {text: "Second", triggered: function() {}},
            {text: "Third", triggered: function() {}},
            {text: "Fourth", triggered: function() {}}
        ]
        tryVerify(() => surface.targetWidth > oldWidth && surface.targetHeight > oldHeight)
        tryVerify(() => surface.running)
        verify(surface.height < surface.targetHeight)
        tryCompare(surface, "running", false, 1000)
        compare(surface.width, 320)
        compare(surface.width, surface.targetWidth)
        compare(surface.height, surface.targetHeight)
        fuzzyCompare(surface.y + surface.height, 900, .5)
    }
}
