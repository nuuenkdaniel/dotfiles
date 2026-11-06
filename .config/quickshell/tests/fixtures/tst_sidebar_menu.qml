import QtQuick
import QtTest
import "." as Fixtures

// The runner places a non-singleton copy of the real GlobalMenuState beside
// this fixture, avoiding imports of unrelated Quickshell hardware services.
TestCase {
    id: testCase
    name: "SidebarMenuPositioning"
    when: windowShown
    property var subject: null
    property var policiesAtTargetChange: []
    Component { id: factory; Fixtures.GlobalMenuState {} }
    Connections {
        target: testCase.subject
        function onTargetYChanged() {
            testCase.policiesAtTargetChange.push(testCase.subject.animatePosition)
        }
    }

    function init() {
        subject = createTemporaryObject(factory, testCase)
        verify(subject !== null)
        policiesAtTargetChange = []
    }

    function test_first_open_disables_motion_before_setting_anchor() {
        subject.openAt(900, [{text: "Wi-Fi"}], 1, true)
        compare(subject.isVisible, true)
        compare(subject.animatePosition, false)
        compare(policiesAtTargetChange.length, 1)
        compare(policiesAtTargetChange[0], false)
        compare(subject.targetY, 900)
    }

    function test_layout_settling_after_first_open_does_not_arm_motion() {
        subject.openAt(900, [], 0, false)
        wait(30)
        subject.menuModel = [{text: "Late tray item"}]
        compare(subject.animatePosition, false)
    }

    function test_switching_open_menus_enables_motion_before_anchor_changes() {
        subject.openAt(900, [{text: "Wi-Fi"}], 1, true)
        subject.openAt(950, [{text: "Bluetooth"}], 2, true)
        compare(subject.animatePosition, true)
        compare(policiesAtTargetChange.length, 2)
        compare(policiesAtTargetChange[1], true)
        compare(subject.menuType, 2)
    }

    function test_same_anchor_new_menu_can_animate_height_correction() {
        subject.openAt(900, [{text: "First tray menu"}], 0, false)
        subject.openAt(900, [{text: "Second"}, {text: "More items"}], 0, false)
        compare(subject.animatePosition, true)
        compare(subject.persist, false)
    }

    function test_closing_then_reopening_resets_initial_placement() {
        subject.openAt(900, [], 1, true)
        subject.openAt(950, [], 2, true)
        subject.isVisible = false
        compare(subject.animatePosition, false)
        subject.openAt(700, [], 0, false)
        compare(subject.animatePosition, false)
        compare(policiesAtTargetChange[policiesAtTargetChange.length - 1], false)
    }

    function test_only_originating_monitor_owns_content() {
        subject.openAt(300, [], 1, true, "eDP-1", 55)
        compare(subject.ownsScreen("eDP-1", "DP-1"), true)
        compare(subject.ownsScreen("DP-1", "DP-1"), false)
        compare(subject.sidebarWidth, 55)
        subject.openAt(500, [], 2, true, "DP-1", 70)
        compare(subject.ownsScreen("DP-1", "eDP-1"), true)
        compare(subject.ownsScreen("eDP-1", "eDP-1"), false)
        compare(subject.animatePosition, false)
        compare(subject.sidebarWidth, 70)
    }

    function test_close_drops_callbacks_and_tray_source() {
        subject.openAt(300, [{text: "Item"}], 0, false, "eDP-1", 55, {name: "Tray"})
        verify(subject.menuSource !== null)
        subject.isVisible = false
        compare(subject.menuSource, null)
        compare(subject.menuModel.length, 0)
    }
}
