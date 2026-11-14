import SwiftUI

extension Binding {
    // Binds by id, so a field that commits after its element was deleted writes nowhere instead of crashing.
    func element<T: Identifiable>(_ element: T) -> Binding<T> where Value == [T] {
        Binding<T>(
            get: { wrappedValue.first { $0.id == element.id } ?? element },
            set: { newValue in
                guard let index = wrappedValue.firstIndex(where: { $0.id == element.id }) else { return }
                wrappedValue[index] = newValue
            }
        )
    }
}

extension Binding where Value == Bool {
    // Shown while `state` holds something; dismissing the dialog any way clears it.
    init<State>(presenting state: Binding<State?>) {
        self.init(get: { state.wrappedValue != nil }, set: { if !$0 { state.wrappedValue = nil } })
    }

    init<Element>(presenting state: Binding<[Element]>) {
        self.init(get: { !state.wrappedValue.isEmpty }, set: { if !$0 { state.wrappedValue = [] } })
    }
}
