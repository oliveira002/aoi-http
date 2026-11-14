import Foundation

extension Store {
    func addEnvironment() {
        let environment = APIEnvironment(name: "New Environment", variables: [KeyValue(key: APIEnvironment.baseURLKey)])
        environments.append(environment)
        detail = .variables(.environment(environment.id))
    }

    func duplicateEnvironment(_ id: UUID) {
        guard let index = environments.firstIndex(where: { $0.id == id }) else { return }
        var copy = environments[index]
        copy.id = UUID()
        copy.name += " copy"
        copy.variables = copy.variables.map { var row = $0; row.id = UUID(); return row }
        environments.insert(copy, at: index + 1)
    }

    func toggleActive(_ id: UUID) {
        activeEnvironmentID = activeEnvironmentID == id ? nil : id
    }

    func toggleProduction(_ id: UUID) {
        guard let environment = environment(id) else { return }
        setProduction(!environment.isProduction, for: id)
    }

    func deleteEnvironment(_ id: UUID) {
        environments.removeAll { $0.id == id }
        if activeEnvironmentID == id { activeEnvironmentID = nil }
        if detail == .variables(.environment(id)) { detail = .request }
    }

    func setProduction(_ on: Bool, for id: UUID) {
        guard let index = environments.firstIndex(where: { $0.id == id }) else { return }
        environments[index].isProduction = on
    }
}
