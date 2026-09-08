import Darwin
import Foundation

public struct Check: Sendable {
    public let name: String
    public let body: @MainActor @Sendable () async throws -> Void

    public init(_ name: String, body: @escaping @MainActor @Sendable () async throws -> Void) {
        self.name = name
        self.body = body
    }
}

public struct CheckFailure: Error, CustomStringConvertible, Sendable {
    public let description: String

    public init(_ description: String) {
        self.description = description
    }
}

public func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String = "Expectation failed"
) throws {
    guard condition() else {
        throw CheckFailure(message)
    }
}

public func require<Value>(
    _ value: Value?,
    _ message: String = "Required value was nil"
) throws -> Value {
    guard let value else {
        throw CheckFailure(message)
    }
    return value
}

public enum TestHarness {
    @MainActor
    public static func run(
        _ checks: [Check],
        arguments: [String] = Array(CommandLine.arguments.dropFirst())
    ) async {
        let selected = arguments.isEmpty
            ? checks
            : checks.filter { check in arguments.contains { check.name.localizedCaseInsensitiveContains($0) } }

        var failureCount = 0
        for check in selected {
            do {
                try await check.body()
                print("PASS: \(check.name)")
            } catch {
                failureCount += 1
                print("FAIL: \(check.name) — \(error)")
            }
        }

        guard !selected.isEmpty else {
            print("FAIL: no checks matched \(arguments.joined(separator: ", "))")
            exit(EXIT_FAILURE)
        }

        print("\(selected.count - failureCount) passed, \(failureCount) failed")
        if failureCount > 0 {
            exit(EXIT_FAILURE)
        }
    }
}
