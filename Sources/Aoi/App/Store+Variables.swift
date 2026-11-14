import Foundation

// Variables from globals, the open collection, the active environment and this session, in that override order.
extension Store {
    var activeScopes: [VariableScope] {
        [.globals, openCollectionID.map(VariableScope.collection), activeEnvironmentID.map(VariableScope.environment), .session].compactMap { $0 }
    }

    var variables: [String: String] {
        activeScopes.reduce(into: [:]) { result, scope in result.merge(rows(in: scope).values) { $1 } }
    }

    func rows(in scope: VariableScope) -> [KeyValue] {
        switch scope {
        case .globals: globals
        case .collection(let id): collection(id)?.variables ?? []
        case .environment(let id): environment(id)?.variables ?? []
        case .session: sessionVariables
        }
    }

    func setRows(_ rows: [KeyValue], in scope: VariableScope) {
        switch scope {
        case .globals:
            globals = rows
        case .collection(let id):
            guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
            collections[index].variables = rows
        case .environment(let id):
            guard let index = environments.firstIndex(where: { $0.id == id }) else { return }
            environments[index].variables = rows
        case .session:
            sessionVariables = rows
        }
    }

    // Variables the open collection's paths and the current request use, for naming a value from a response.
    var variablesInUse: [String] {
        let paths = (openCollection?.requests ?? []).flatMap { RequestDraft.pathVariables(in: $0.draft.pathTemplate ?? $0.draft.url) }
        return (draft.unresolvedVariables(variables) + paths).uniqued()
    }

    // A value taken from a response, kept for this session only.
    func setVariable(_ name: String, to value: String) {
        sessionVariables = sessionVariables.setting(name, to: value)
    }

    // Opens a scope's variables, with the sidebar on the tab that lists it.
    func showVariables(_ scope: VariableScope) {
        if case .collection = scope { sidebarTab = .collections } else { sidebarTab = .environments }
        detail = .variables(scope)
    }

    // Adds empty rows for the given names and opens that scope, so the user only types the values.
    func addMissing(_ names: [String], to scope: VariableScope) {
        // A switched-off row would keep the value unset, so turn those back on.
        let current = rows(in: scope).map { row in
            var row = row
            if names.contains(row.key) { row.enabled = true }
            return row
        }
        let existing = Set(current.map(\.key))
        setRows(current + names.filter { !existing.contains($0) }.map { KeyValue(key: $0) }, in: scope)
        detail = .variables(scope)
    }

    // Another environment that has values for these names, preferring the same stage (the last word, e.g. DEV).
    func environmentDefining(_ names: [String]) -> APIEnvironment? {
        let stage = activeEnvironment?.name.split(separator: " ").last
        let candidates = environments.filter { environment in
            environment.id != activeEnvironmentID && names.contains { environment.variables.values[$0] != nil }
        }
        return candidates.first { $0.name.split(separator: " ").last == stage } ?? candidates.first
    }
}
