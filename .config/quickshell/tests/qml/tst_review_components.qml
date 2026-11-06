import QtQuick
import QtTest
import "../../components"

TestCase {
    id: testCase
    name: "ReviewComponents"
    when: windowShown
    property var subject
    property string subjectKind: ""
    Component {
        id: stableFactory
        Item {
            id: container
            property int creations: 0
            property int removals: 0
            property alias entries: stable.values
            property alias rows: repeater
            property alias first: a
            property alias second: b
            QtObject { id: a; property string name: "first" }
            QtObject { id: b; property string name: "second" }
            StableObjectModel { id: stable; values: [a, b] }
            Repeater {
                id: repeater
                model: stable.model
                Item {
                    required property var entryObject
                    property string draft: ""
                    Component.onCompleted: container.creations++
                    Component.onDestruction: container.removals++
                }
            }
        }
    }
    Component {
        id: pageFactory
        LazySettingsPage {
            width: 200; height: 200
            sourceComponent: Item { property string draft: "saved draft" }
        }
    }
    Component { id: expiryFactory; NotificationExpiry { duration: 120 } }
    Component {
        id: menuFactory
        PopupMenuContent { width: implicitWidth; height: implicitHeight; maximumHeight: 120 }
    }
    SignalSpy { id: expired; target: testCase.subjectKind === "expiry" ? testCase.subject : null; signalName: "expired" }
    SignalSpy { id: activated; target: testCase.subjectKind === "menu" ? testCase.subject : null; signalName: "entryActivated" }
    SignalSpy { id: closed; target: testCase.subjectKind === "menu" ? testCase.subject : null; signalName: "closeRequested" }

    function cleanup() { subjectKind = "" }

    function test_reordering_preserves_delegates_and_drafts() {
        subject = createTemporaryObject(stableFactory, testCase)
        compare(subject.rows.count, 2)
        const firstRow = subject.rows.itemAt(0)
        firstRow.draft = "editing"
        subject.entries = [subject.second, subject.first]
        compare(subject.creations, 2)
        compare(subject.removals, 0)
        compare(subject.rows.itemAt(1), firstRow)
        compare(firstRow.draft, "editing")
        subject.entries = [subject.first]
        compare(subject.rows.count, 1)
        compare(subject.rows.itemAt(0), firstRow)
        compare(subject.removals, 1)
    }

    function test_page_is_lazy_and_retains_drafts_after_hiding() {
        subject = createTemporaryObject(pageFactory, testCase)
        compare(subject.item, null)
        subject.selected = true
        compare(subject.item, null)
        subject.panelActive = true
        verify(subject.item !== null)
        const page = subject.item
        page.draft = "edited"
        subject.panelActive = false
        subject.selected = false
        compare(subject.item, page)
        subject.selected = true
        subject.panelActive = true
        compare(subject.item.draft, "edited")
    }

    function test_expiry_uses_a_single_deadline() {
        subject = createTemporaryObject(expiryFactory, testCase)
        subjectKind = "expiry"
        expired.clear()
        tryCompare(expired, "count", 1, 500)
        wait(80)
        compare(expired.count, 1)
    }

    function test_expiry_pauses_on_hover_and_resumes_remaining_time() {
        subject = createTemporaryObject(expiryFactory, testCase)
        subjectKind = "expiry"
        expired.clear()
        wait(40)
        subject.paused = true
        verify(subject.remaining > 0 && subject.remaining < subject.duration)
        wait(160)
        compare(expired.count, 0)
        subject.paused = false
        tryCompare(expired, "count", 1, 400)
    }

    function test_persistent_notification_has_no_expiry() {
        subject = createTemporaryObject(expiryFactory, testCase, {duration: 0})
        subjectKind = "expiry"
        expired.clear()
        wait(160)
        compare(expired.count, 0)
    }

    function test_expiry_restart_and_close_cancel_old_deadlines() {
        subject = createTemporaryObject(expiryFactory, testCase)
        subjectKind = "expiry"
        expired.clear()
        wait(70)
        subject.restart()
        wait(70)
        compare(expired.count, 0)
        subject.active = false
        wait(100)
        compare(expired.count, 0)
    }

    function test_menu_bounds_keyboard_navigation_and_escape() {
        subject = createTemporaryObject(menuFactory, testCase, {menuModel: [
            {text: "Header", isHeader: true}, {text: "Disabled", enabled: false},
            {text: "First", triggered: function() {}}, {isSeparator: true},
            {text: "Second", triggered: function() {}}, {text: "Last", triggered: function() {}}
        ]})
        verify(subject.height <= 120)
        subject.forceActiveFocus()
        tryCompare(subject, "currentIndex", 2)
        keyClick(Qt.Key_Down)
        compare(subject.currentIndex, 4)
        subjectKind = "menu"
        activated.clear()
        keyClick(Qt.Key_Return)
        compare(activated.count, 1)
        compare(activated.signalArguments[0][0].text, "Second")
        closed.clear()
        keyClick(Qt.Key_Escape)
        compare(closed.count, 1)
    }

    function test_menu_labels_are_plain_text_and_keep_literal_network_ampersands() {
        subject = createTemporaryObject(menuFactory, testCase, {menuModel: [
            {text: "<b>A&B</b>", triggered: function() {}}
        ]})
        const label = findChild(subject, "menuCaption")
        verify(label !== null)
        compare(label.textFormat, Text.PlainText)
        compare(label.text, "<b>A&B</b>")
    }

    function test_native_menu_check_state_and_mnemonics() {
        subject = createTemporaryObject(menuFactory, testCase, {menuModel: [
            {text: "&Enabled && ready", buttonType: 1, checkState: Qt.Checked, triggered: function() {}}
        ]})
        const label = findChild(subject, "menuCaption")
        compare(label.text, "✓ Enabled & ready")
    }
}
