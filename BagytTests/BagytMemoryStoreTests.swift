import XCTest
@testable import Bagyt

final class BagytMemoryStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BagytTestSupport.resetDefaults()
    }

    override func tearDown() {
        BagytTestSupport.resetDefaults()
        super.tearDown()
    }

    func testVisibleAssistantTextRemovesAnamnesisBlockAndMarkdown() {
        let raw = """
        **Короткий ответ**

        BAGYT_ANAMNESIS_JSON
        {"should_save":true,"title":"Скрыто","summary":"JSON не должен быть виден"}
        END_BAGYT_ANAMNESIS_JSON

        ## Что дальше
        - **Пейте воду** и наблюдайте.
        """

        let visible = BagytMemoryStore.visibleAssistantText(from: raw)

        XCTAssertTrue(visible.contains("Короткий ответ"))
        XCTAssertTrue(visible.contains("Что дальше"))
        XCTAssertTrue(visible.contains("- Пейте воду и наблюдайте."))
        XCTAssertFalse(visible.contains("BAGYT_ANAMNESIS_JSON"))
        XCTAssertFalse(visible.contains("should_save"))
        XCTAssertFalse(visible.contains("**"))
        XCTAssertFalse(visible.contains("##"))
    }

    func testGeneratedAnamnesisIsCapturedAsStructuredFinding() {
        let assistant = """
        Спасибо, давайте разберемся.

        BAGYT_ANAMNESIS_JSON
        {"should_save":true,"title":"Боль в ноге","summary":"Боль усиливается к вечеру","hypotheses":["мышечная усталость","перенапряжение"],"red_flags":["отек","сильная боль"],"next_steps":["наблюдать динамику","обратиться к врачу при ухудшении"]}
        END_BAGYT_ANAMNESIS_JSON
        """

        BagytMemoryStore.shared.deleteAllFindings(token: BagytTestSupport.userA)
        BagytMemoryStore.shared.captureAIResponse(
            userText: "Болит нога к вечеру",
            assistantText: assistant,
            token: BagytTestSupport.userA
        )

        let finding = BagytMemoryStore.shared.loadFindings(token: BagytTestSupport.userA).first

        XCTAssertEqual(finding?.title, "Боль в ноге")
        XCTAssertEqual(finding?.summary, "Боль усиливается к вечеру")
        XCTAssertEqual(finding?.userText, "Болит нога к вечеру")
        XCTAssertEqual(finding?.assistantText, "Спасибо, давайте разберемся.")
        XCTAssertEqual(finding?.hypotheses, ["мышечная усталость", "перенапряжение"])
        XCTAssertEqual(finding?.redFlags, ["отек", "сильная боль"])
        XCTAssertEqual(finding?.nextSteps, ["наблюдать динамику", "обратиться к врачу при ухудшении"])
    }

    func testFindingsAreScopedByToken() {
        BagytMemoryStore.shared.deleteAllFindings(token: BagytTestSupport.userA)
        BagytMemoryStore.shared.deleteAllFindings(token: BagytTestSupport.userB)

        BagytMemoryStore.shared.captureAIResponse(
            userText: "Болит голова",
            assistantText: generatedAnswer(title: "Головная боль"),
            token: BagytTestSupport.userA
        )
        BagytMemoryStore.shared.captureAIResponse(
            userText: "Болит живот",
            assistantText: generatedAnswer(title: "Боль в животе"),
            token: BagytTestSupport.userB
        )

        XCTAssertEqual(BagytMemoryStore.shared.loadFindings(token: BagytTestSupport.userA).map(\.title), ["Головная боль"])
        XCTAssertEqual(BagytMemoryStore.shared.loadFindings(token: BagytTestSupport.userB).map(\.title), ["Боль в животе"])
    }

    func testDuplicateFindingsAreNotInsertedTwice() {
        let assistant = generatedAnswer(title: "Повтор симптома")

        BagytMemoryStore.shared.captureAIResponse(
            userText: "Температура и кашель",
            assistantText: assistant,
            token: BagytTestSupport.userA
        )
        BagytMemoryStore.shared.captureAIResponse(
            userText: "Температура и кашель",
            assistantText: assistant,
            token: BagytTestSupport.userA
        )

        XCTAssertEqual(BagytMemoryStore.shared.loadFindings(token: BagytTestSupport.userA).count, 1)
    }

    func testDeleteAllFindingsOnlyClearsSelectedUser() {
        BagytMemoryStore.shared.captureAIResponse(
            userText: "Болит горло",
            assistantText: generatedAnswer(title: "Горло"),
            token: BagytTestSupport.userA
        )
        BagytMemoryStore.shared.captureAIResponse(
            userText: "Болит спина",
            assistantText: generatedAnswer(title: "Спина"),
            token: BagytTestSupport.userB
        )

        BagytMemoryStore.shared.deleteAllFindings(token: BagytTestSupport.userA)

        XCTAssertTrue(BagytMemoryStore.shared.loadFindings(token: BagytTestSupport.userA).isEmpty)
        XCTAssertEqual(BagytMemoryStore.shared.loadFindings(token: BagytTestSupport.userB).count, 1)
    }

    func testLifestyleOnlyMessageIsNotCapturedWithoutMedicalSignal() {
        BagytMemoryStore.shared.captureAIResponse(
            userText: "Сколько воды пить за день?",
            assistantText: "Обычно ориентируются на самочувствие и активность.",
            token: BagytTestSupport.userA
        )

        XCTAssertTrue(BagytMemoryStore.shared.loadFindings(token: BagytTestSupport.userA).isEmpty)
    }

    private func generatedAnswer(title: String) -> String {
        """
        Видимый ответ.
        BAGYT_ANAMNESIS_JSON
        {"should_save":true,"title":"\(title)","summary":"Краткое резюме","hypotheses":["возможная причина"],"red_flags":["красный флаг"],"next_steps":["следующий шаг"]}
        END_BAGYT_ANAMNESIS_JSON
        """
    }
}
