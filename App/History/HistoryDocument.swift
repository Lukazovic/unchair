import SwiftUI
import UnchairCore
import UniformTypeIdentifiers

/// History exported as JSON or CSV through the save panel.
struct HistoryDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json, .commaSeparatedText]

    var history: History

    init(history: History) {
        self.history = history
    }

    init(configuration _: ReadConfiguration) throws {
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = if configuration.contentType == .commaSeparatedText {
            Data(history.csv().utf8)
        } else {
            try history.jsonData()
        }
        return FileWrapper(regularFileWithContents: data)
    }
}
