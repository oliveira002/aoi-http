import Foundation
import Testing
@testable import Aoi

struct AppSettingsTests {
    @Test func missingKeysUseDefaults() throws {
        // Arrange
        let saved = #"{"timeout": 15}"#

        // Act
        let victim = try JSONDecoder().decode(AppSettings.self, from: Data(saved.utf8))

        // Assert
        #expect(victim.timeout == 15)
        #expect(victim.historyLimit == 500)
        #expect(victim.productionGuard == .writes)
    }

    @Test func savedValuesSnapToTheNearestPreset() throws {
        // Arrange
        let saved = #"{"timeout": 100, "historyLimit": -5, "jsonExpandLevels": 99}"#

        // Act
        let victim = try JSONDecoder().decode(AppSettings.self, from: Data(saved.utf8))

        // Assert
        #expect(victim.timeout == 120)
        #expect(victim.historyLimit == 100)
        #expect(victim.jsonExpandLevels == 3)
    }

    @Test(arguments: HTTPMethod.allCases)
    func everyRequestAsksForAnyMethod(method: HTTPMethod) {
        // Arrange
        var victim = AppSettings()
        victim.productionGuard = .all

        // Act
        let result = victim.asksBeforeSending(method)

        // Assert
        #expect(result)
    }

    @Test(arguments: HTTPMethod.allCases)
    func neverAskSkipsEveryMethod(method: HTTPMethod) {
        // Arrange
        var victim = AppSettings()
        victim.productionGuard = .off

        // Act
        let result = victim.asksBeforeSending(method)

        // Assert
        #expect(!result)
    }

    @Test(arguments: [(HTTPMethod.GET, false), (.HEAD, false), (.OPTIONS, false), (.POST, true), (.PUT, true), (.PATCH, true), (.DELETE, true)])
    func onlyChangesAsksForWrites(method: HTTPMethod, asks: Bool) {
        // Arrange
        var victim = AppSettings()
        victim.productionGuard = .writes

        // Act
        let result = victim.asksBeforeSending(method)

        // Assert
        #expect(result == asks)
    }
}

struct APIEnvironmentTests {
    @Test(arguments: [("API PRD", true), ("prod-library", true), ("Production", true), ("API DEV", false), ("Productive readers", false), ("PRDX", false)])
    func recognisesProductionNames(name: String, production: Bool) {
        // Arrange / Act
        let victim = APIEnvironment(name: name)

        // Assert
        #expect(victim.isProduction == production)
    }

    @Test func renamingToProductionTurnsTheGuardOn() {
        // Arrange
        var victim = APIEnvironment(name: "New Environment")

        // Act
        victim.name = "Library PRD"

        // Assert
        #expect(victim.isProduction)
    }

    @Test func renamingNeverTurnsTheGuardOff() {
        // Arrange
        var victim = APIEnvironment(name: "API PRD")

        // Act
        victim.name = "API DEV"

        // Assert
        #expect(victim.isProduction)
    }

    @Test func oldFilesInferProductionFromTheName() throws {
        // Arrange
        let saved = #"{"id":"11111111-2222-3333-4444-555555555555","name":"API PRD","variables":[]}"#

        // Act
        let victim = try JSONDecoder().decode(APIEnvironment.self, from: Data(saved.utf8))

        // Assert
        #expect(victim.isProduction)
    }

    @Test func aSavedFlagWinsOverTheName() throws {
        // Arrange
        let saved = #"{"id":"11111111-2222-3333-4444-555555555555","name":"API PRD","variables":[],"isProduction":false}"#

        // Act
        let victim = try JSONDecoder().decode(APIEnvironment.self, from: Data(saved.utf8))

        // Assert
        #expect(!victim.isProduction)
    }
}

struct PersistenceTests {
    @Test func savesAndLoadsAFile() {
        // Arrange
        let victim = Persistence.temporary()
        let globals = [KeyValue(key: "token", value: "abc")]

        // Act
        victim.save(globals, to: .globals)

        // Assert
        #expect(victim.load(.globals) == globals)
    }

    @Test func movesAnUnreadableFileAside() throws {
        // Arrange
        let victim = Persistence.temporary()
        try FileManager.default.createDirectory(at: victim.directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: victim.directory.appending(path: "globals.json"))

        // Act
        let loaded = victim.load(.globals)

        // Assert
        #expect(loaded == nil)
        #expect(FileManager.default.fileExists(atPath: victim.directory.appending(path: "globals.json.bak").path))
    }
}

struct EnvironmentBaseURLTests {
    @Test func readsTheBaseURLVariable() {
        // Arrange / Act
        let victim = APIEnvironment(name: "DEV", variables: [KeyValue(key: "baseUrl", value: "https://api.test"), KeyValue(key: "shelf", value: "north")])

        // Assert
        #expect(victim.baseURL == "https://api.test")
        #expect(victim.otherVariables.map(\.key) == ["shelf"])
    }

    @Test func settingTheBaseURLAddsItWhenMissing() {
        // Arrange
        var victim = APIEnvironment(name: "DEV")

        // Act
        victim.baseURL = "https://api.test"

        // Assert
        #expect(victim.variables.values == ["baseUrl": "https://api.test"])
    }

    @Test func editingOtherVariablesKeepsTheBaseURL() {
        // Arrange
        var victim = APIEnvironment(name: "DEV", variables: [KeyValue(key: "baseUrl", value: "https://api.test")])

        // Act
        victim.otherVariables = [KeyValue(key: "shelf", value: "north")]

        // Assert
        #expect(victim.variables.values == ["baseUrl": "https://api.test", "shelf": "north"])
    }
}

@MainActor
struct EnvironmentBaseURLStoreTests {
    @Test func aNewEnvironmentStartsWithAnEmptyBaseURL() {
        // Arrange
        let victim = makeStore()

        // Act
        victim.addEnvironment()

        // Assert
        #expect(victim.environments[0].variables.map(\.key) == ["baseUrl"])
    }

    @Test func theActiveEnvironmentsBaseURLFillsRequests() {
        // Arrange
        let victim = makeStore()
        var environment = APIEnvironment(name: "API DEV")
        environment.baseURL = "https://api.test"
        victim.environments = [environment]
        victim.activeEnvironmentID = environment.id

        // Act
        victim.draft.url = "{{baseUrl}}/v1/books"

        // Assert
        #expect(victim.resolvedURL == "https://api.test/v1/books")
    }
}
