import QtQuick
import QtQml.Models

Item {
    id: root
    property var values: []
    property alias model: records
    visible: false
    ListModel { id: records }
    onValuesChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        const next = values.filter(value => !!value)
        for (let i = records.count - 1; i >= 0; --i) {
            if (!next.includes(records.get(i).entryObject)) records.remove(i)
        }
        for (let i = 0; i < next.length; ++i) {
            let existing = -1
            for (let j = i; j < records.count; ++j) {
                if (records.get(j).entryObject === next[i]) { existing = j; break }
            }
            if (existing < 0) records.insert(i, {entryObject: next[i]})
            else if (existing !== i) records.move(existing, i, 1)
        }
    }
}
