import XCTest
@testable import Bagyt

final class ChatLocalStorageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BagytTestSupport.resetDefaults()
    }

    override func tearDown() {
        BagytTestSupport.resetDefaults()
        super.tearDown()
    }

    func testChatHistoryIsScopedByUserToken() {
        BagytTestSupport.setUser(BagytTestSupport.userA)
        ChatService.shared.saveMessages([
            ChatMessage(text: "Привет", sender: .user),
            ChatMessage(text: "Здравствуйте", sender: .assistant)
        ])

        BagytTestSupport.setUser(BagytTestSupport.userB)
        XCTAssertTrue(ChatService.shared.loadMessages().isEmpty)

        ChatService.shared.saveMessages([
            ChatMessage(text: "Hello", sender: .user)
        ])

        XCTAssertEqual(ChatService.shared.loadMessages().map(\.text), ["Hello"])

        BagytTestSupport.setUser(BagytTestSupport.userA)
        XCTAssertEqual(ChatService.shared.loadMessages().map(\.text), ["Привет", "Здравствуйте"])
    }

    func testClearMessagesOnlyClearsCurrentUser() {
        BagytTestSupport.setUser(BagytTestSupport.userA)
        ChatService.shared.saveMessages([ChatMessage(text: "A", sender: .user)])

        BagytTestSupport.setUser(BagytTestSupport.userB)
        ChatService.shared.saveMessages([ChatMessage(text: "B", sender: .user)])
        ChatService.shared.clearMessages()

        XCTAssertTrue(ChatService.shared.loadMessages().isEmpty)

        BagytTestSupport.setUser(BagytTestSupport.userA)
        XCTAssertEqual(ChatService.shared.loadMessages().map(\.text), ["A"])
    }

    func testChatMessageCodableRoundTripKeepsSenderTextAndDate() throws {
        let original = ChatMessage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            text: "Текст",
            sender: .assistant,
            date: Date(timeIntervalSince1970: 1234)
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: data)

        XCTAssertEqual(decoded, original)
    }
}
