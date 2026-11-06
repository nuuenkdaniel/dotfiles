import QtQuick
import QtTest
import "../../components"

TestCase {
    id: testCase
    name: "ShellTooltips"
    when: windowShown
    Component { id: tipFactory; ShellToolTip {} }
    Component { id: calendarFactory; CalendarPreview { date: new Date(2026, 10, 1, 12) } }

    function test_tooltip_uses_shell_colours_and_plain_text() {
        const tip = createTemporaryObject(tipFactory, testCase)
        verify(tip !== null)
        tip.text = "<b>Device description</b>"
        compare(tip.background.color.toString(), "#242133")
        compare(tip.background.border.color.toString(), "#4a405b")
        compare(tip.contentItem.color.toString(), "#cdd6f4")
        compare(tip.contentItem.textFormat, Text.PlainText)
        compare(tip.contentItem.text, "<b>Device description</b>")
        verify(tip.background.radius > 0)
    }

    function test_tooltip_caps_long_text_width() {
        const tip = createTemporaryObject(tipFactory, testCase)
        tip.text = "A very long audio device description ".repeat(30)
        verify(tip.width <= 320)
        compare(tip.contentItem.wrapMode, Text.Wrap)
    }

    function test_calendar_shows_six_weeks_and_highlights_today() {
        const calendar = createTemporaryObject(calendarFactory, testCase)
        verify(calendar !== null)
        const days = findChild(calendar, "calendarDays")
        compare(days.count, 42)
        compare(days.itemAt(0).modelData.day, 26)
        compare(days.itemAt(0).thisMonth, false)
        compare(days.itemAt(6).modelData.day, 1)
        compare(days.itemAt(6).today, true)
        let highlighted = 0
        for (let i = 0; i < days.count; i++) if (days.itemAt(i).today) highlighted++
        compare(highlighted, 1)
    }

    function test_calendar_updates_for_leap_day() {
        const calendar = createTemporaryObject(calendarFactory, testCase)
        calendar.date = new Date(2028, 1, 29, 12)
        const days = findChild(calendar, "calendarDays")
        compare(days.count, 42)
        let today = null
        for (let i = 0; i < days.count; i++) if (days.itemAt(i).today) today = days.itemAt(i)
        verify(today !== null)
        compare(today.modelData.day, 29)
        compare(today.modelData.month, 1)
        compare(today.modelData.year, 2028)
    }
}
