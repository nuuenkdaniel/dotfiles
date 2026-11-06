import QtQuick
import QtTest
import "../../components"

TestCase {
    id: testCase
    name: "SidebarMenuReveal"
    width: 400
    height: 300
    visible: true
    when: windowShown
    property var subject
    Component { id: factory; SidebarMenuReveal {} }
    Component { id: initiallyOpenFactory; SidebarMenuReveal { opened: true } }
    Component {
        id: backgroundFactory
        Rectangle {
            width: 240; height: 200; color: "#6f3456"
            SidebarMenuBackground { width: parent.width; panelHeight: 160 }
        }
    }

    function init() {
        subject = createTemporaryObject(factory, testCase)
        verify(subject !== null)
    }

    function test_first_open_slides_horizontally_instead_of_popping_in() {
        compare(subject.progress, 0)
        subject.opened = true
        compare(subject.offset, -28)
        verify(subject.running)
        wait(60)
        verify(subject.offset > -28 && subject.offset < 0)
        tryCompare(subject, "running", false, 600)
        compare(subject.offset, 0)
        compare(subject.progress, 1)
    }

    function test_every_fresh_open_restarts_the_slide() {
        subject.opened = true
        tryCompare(subject, "running", false, 600)
        subject.opened = false
        compare(subject.progress, 0)
        subject.opened = true
        compare(subject.offset, -28)
        verify(subject.running)
    }

    function test_switching_an_already_open_menu_does_not_restart_reveal() {
        subject.opened = true
        tryCompare(subject, "running", false, 600)
        subject.opened = true
        compare(subject.progress, 1)
        compare(subject.running, false)
    }

    function test_closing_during_entrance_cancels_animation() {
        subject.opened = true
        wait(40)
        subject.opened = false
        compare(subject.running, false)
        compare(subject.progress, 0)
    }

    function test_initially_open_component_also_animates() {
        const opened = createTemporaryObject(initiallyOpenFactory, testCase)
        verify(opened.running)
        compare(opened.progress, 0)
        tryCompare(opened, "running", false, 600)
        compare(opened.offset, 0)
    }

    function test_attachment_shoulders_have_transparent_negative_space() {
        const background = createTemporaryObject(backgroundFactory, testCase)
        verify(waitForRendering(background))
        const image = grabImage(background)
        compare(image.pixel(100, 5).toString(), "#6f3456")
        compare(image.pixel(100, 195).toString(), "#6f3456")
        compare(image.pixel(2, 17).toString(), "#1e1e2e")
        compare(image.pixel(100, 80).toString(), "#1e1e2e")
    }
}
