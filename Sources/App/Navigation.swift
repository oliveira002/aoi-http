import Foundation

enum SidebarTab: String, CaseIterable {
    case collections = "Collections", history = "History", environments = "Environments"
}

// Where a variable lives. Later scopes override earlier ones: globals, then a collection, then an environment.
enum VariableScope: Hashable {
    // session holds values taken from responses; it lives in memory only and wins over the rest.
    case globals, collection(UUID), environment(UUID), session
}

enum Detail: Hashable {
    case request, variables(VariableScope)
}

enum Deletion: Equatable {
    case collection(UUID), environment(UUID)
}
