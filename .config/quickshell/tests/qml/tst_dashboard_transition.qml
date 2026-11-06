import QtQuick
import QtTest
import "../../components"

TestCase {
    id: testCase
    name: "DashboardTransition"
    when: windowShown
    property var subject
    Component { id: factory; DashboardTransition {} }
    SignalSpy { id: presentationSpy; target: testCase.subject; signalName: "presentedChanged" }

    function init() {
        subject = createTemporaryObject(factory, testCase)
        verify(subject !== null)
        presentationSpy.clear()
    }

    function openFully() {
        subject.opened = true
        tryCompare(subject, "running", false, 1000)
        compare(subject.presented, true)
        compare(subject.progress, 1)
        presentationSpy.clear()
    }

    function test_starts_unmapped() {
        compare(subject.presented, false)
        compare(subject.running, false)
    }

    function test_close_preserves_content_until_animation_finishes() {
        openFully()
        subject.opened = false
        compare(subject.presented, true)
        compare(presentationSpy.count, 0)
        wait(60)
        compare(subject.presented, true)
        verify(subject.progress > 0)
        tryCompare(subject, "presented", false, 1000)
        compare(subject.progress, 0)
        compare(presentationSpy.count, 1)
    }

    function test_reversing_close_never_unmaps_or_reloads_content() {
        openFully()
        subject.opened = false
        wait(60)
        subject.opened = true
        compare(subject.presented, true)
        compare(presentationSpy.count, 0)
        tryCompare(subject, "running", false, 1000)
        compare(subject.progress, 1)
        compare(presentationSpy.count, 0)
    }

    function test_close_during_opening_does_not_flash_hidden_then_visible() {
        subject.opened = true
        wait(60)
        presentationSpy.clear()
        subject.opened = false
        compare(subject.presented, true)
        compare(presentationSpy.count, 0)
        tryCompare(subject, "presented", false, 1000)
        compare(presentationSpy.count, 1)
    }

    function test_reduced_motion_also_preserves_content_during_close() {
        subject.reducedMotion = true
        openFully()
        subject.opened = false
        compare(subject.presented, true)
        compare(presentationSpy.count, 0)
        tryCompare(subject, "presented", false, 500)
        compare(presentationSpy.count, 1)
    }
}
