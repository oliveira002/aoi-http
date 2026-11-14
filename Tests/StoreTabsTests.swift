import Foundation
import Testing
@testable import Aoi

@MainActor
struct StoreTabsTests {
    let book = request("Get book", url: "{{host}}/v1/books/{{book_id}}")
    let list = request("List", url: "{{host}}/v1/books")

    func storeWithCollection(_ requests: [SavedRequest]) -> (Store, UUID) {
        let store = makeStore()
        var collection = APICollection(name: "C")
        collection.requests = requests
        store.collections = [collection]
        return (store, collection.id)
    }

    @Test func theFirstRequestFillsTheBlankTab() {
        // Arrange
        let (victim, collection) = storeWithCollection([book])

        // Act
        victim.open(book, in: collection)

        // Assert
        #expect(victim.tabs.count == 1)
        #expect(victim.openRequestID == book.id)
    }

    @Test func eachRequestGetsItsOwnTab() {
        // Arrange
        let (victim, collection) = storeWithCollection([book, list])
        victim.open(book, in: collection)

        // Act
        victim.open(list, in: collection)

        // Assert
        #expect(victim.tabs.map { victim.title(of: $0) } == ["Get book", "List"])
        #expect(victim.activeTabID == victim.tabs[1].id)
    }

    @Test func anOpenRequestSwitchesToItsTab() {
        // Arrange
        let (victim, collection) = storeWithCollection([book, list])
        victim.open(book, in: collection)
        victim.open(list, in: collection)

        // Act
        victim.open(book, in: collection)

        // Assert
        #expect(victim.tabs.count == 2)
        #expect(victim.openRequestID == book.id)
    }

    @Test func closingAnEditedTabAsksFirst() {
        // Arrange
        let (victim, collection) = storeWithCollection([book])
        victim.open(book, in: collection)
        victim.draft.url += "/x"

        // Act
        victim.closeTab(victim.activeTabID)

        // Assert
        #expect(victim.pendingClose == victim.activeTabID)
        #expect(victim.openRequestID == book.id)
    }

    @Test func anEditedScratchTabCountsAsChanged() {
        // Arrange
        let victim = makeStore()

        // Act
        victim.draft.url = "https://typed.test"

        // Assert
        #expect(victim.isDirty)
    }

    @Test func closingTheLastTabLeavesABlankOne() {
        // Arrange
        let (victim, collection) = storeWithCollection([book])
        victim.open(book, in: collection)

        // Act
        victim.closeTab(victim.activeTabID)

        // Assert
        #expect(victim.tabs.count == 1)
        #expect(victim.activeTab.isBlank)
    }

    @Test func closeOthersKeepsEditedTabsPending() {
        // Arrange
        let (victim, collection) = storeWithCollection([book, list])
        victim.open(book, in: collection)
        victim.open(list, in: collection)
        victim.draft.url += "/edit"
        victim.newRequest()
        let kept = victim.activeTabID

        // Act
        victim.closeOtherTabs(kept)

        // Assert
        #expect(victim.tabs.count == 2)
        #expect(victim.pendingTabClose.count == 1)
        #expect(victim.activeTabID == kept)
    }

    @Test func closeTabsToTheRight() {
        // Arrange
        let (victim, collection) = storeWithCollection([book, list])
        victim.open(book, in: collection)
        victim.open(list, in: collection)

        // Act
        victim.closeTabsToRight(victim.tabs[0].id)

        // Assert
        #expect(victim.tabs.map { victim.title(of: $0) } == ["Get book"])
    }

    @Test func discardingPendingTabsClosesThem() {
        // Arrange
        let victim = makeStore()
        victim.draft.url = "https://typed.test"
        victim.closeAllTabs()

        // Act
        victim.discardTabs(victim.pendingTabClose)

        // Assert
        #expect(victim.pendingTabClose.isEmpty)
        #expect(victim.activeTab.isBlank)
    }

    @Test func nextTabWrapsAround() {
        // Arrange
        let victim = makeStore()
        victim.newRequest()

        // Act
        victim.selectAdjacentTab(1)

        // Assert
        #expect(victim.activeTabID == victim.tabs[0].id)
    }

    @Test func deletingARequestDetachesItsTabs() {
        // Arrange
        let (victim, collection) = storeWithCollection([book])
        victim.open(book, in: collection)

        // Act
        victim.deleteRequest(book.id, in: collection)

        // Assert
        #expect(victim.openRequestID == nil)
    }

    @Test func aSendingTabIsNotReplaced() {
        // Arrange
        let (victim, collection) = storeWithCollection([book])
        victim.activeTab.isSending = true
        let sending = victim.activeTabID

        // Act
        victim.open(book, in: collection)

        // Assert
        #expect(victim.tabs.contains { $0.id == sending })
        #expect(victim.activeTabID != sending)
    }

    @Test func aResponseLandsInTheTabThatSentIt() async {
        // Arrange
        let (victim, collection) = storeWithCollection([book, list])
        victim.open(book, in: collection)
        victim.draft.url = "https://example.test/books/1"
        let sender = victim.activeTabID

        // Act
        await victim.send()

        // Assert
        #expect(victim.tabs.first { $0.id == sender }?.response?.statusCode == 200)
    }

    @Test func discardingTheCloseRemovesTheTab() {
        // Arrange
        let (victim, collection) = storeWithCollection([book, list])
        victim.open(book, in: collection)
        victim.open(list, in: collection)
        victim.draft.url += "/x"
        victim.closeTab(victim.activeTabID)

        // Act
        victim.finishClose(victim.activeTabID, saving: false)

        // Assert
        #expect(victim.tabs.map { victim.title(of: $0) } == ["Get book"])
        #expect(victim.collections[0].requests[1].draft.url == list.draft.url)
    }

    @Test func savingTheCloseKeepsTheEdits() {
        // Arrange
        let (victim, collection) = storeWithCollection([book])
        victim.open(book, in: collection)
        victim.draft.url += "/x"
        victim.closeTab(victim.activeTabID)

        // Act
        victim.finishClose(victim.activeTabID, saving: true)

        // Assert
        #expect(victim.collections[0].requests[0].draft.url == book.draft.url + "/x")
    }

    @Test func closingWorksAfterTheDialogClearedItsState() {
        // Arrange
        let (victim, collection) = storeWithCollection([book])
        victim.open(book, in: collection)
        victim.draft.url += "/x"
        let closing = victim.activeTabID
        victim.closeTab(closing)
        victim.pendingClose = nil

        // Act
        victim.finishClose(closing, saving: true)

        // Assert
        #expect(victim.collections[0].requests[0].draft.url == book.draft.url + "/x")
        #expect(victim.activeTab.isBlank)
    }
}
