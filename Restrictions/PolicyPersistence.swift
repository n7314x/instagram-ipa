import Foundation

final class PolicyPersistence: @unchecked Sendable {
    let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.fileURL = base
                .appendingPathComponent("InstagramShell", isDirectory: true)
                .appendingPathComponent("policy-state.json", isDirectory: false)
        }
    }

    func load() -> PersistedPolicyState {
        lock.withLock {
            guard let data = try? Data(contentsOf: fileURL),
                  let state = try? JSONDecoder.policyDecoder.decode(PersistedPolicyState.self, from: data) else {
                return PersistedPolicyState()
            }
            return state
        }
    }

    @discardableResult
    func save(_ state: PersistedPolicyState) -> Bool {
        lock.withLock {
            do {
                try fileManager.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let data = try JSONEncoder.policyEncoder.encode(state)
                try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
                return true
            } catch {
                return false
            }
        }
    }
}

private extension JSONEncoder {
    static var policyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var policyDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
