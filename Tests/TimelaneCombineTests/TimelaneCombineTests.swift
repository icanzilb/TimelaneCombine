import XCTest
@testable import TimelaneCore
import TimelaneCoreTestUtils
import Combine
@testable import TimelaneCombine

final class TimelaneCombineTests: XCTestCase {
    
    /// Test the events emitted by a sync array publisher
    func testEmitsEventsFromCompletingPublisher() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        _ = [1, 2, 3].publisher
            .lane("Test Subscription", filter: .event, logger: recorder.log)
            .sink(receiveValue: {_ in })
        
        XCTAssertEqual(recorder.logged.count, 4)
        guard recorder.logged.count == 4 else {
            return
        }
        
        XCTAssertEqual(recorder.logged[0].outputTldr, "Output, Test Subscription, 1")
        XCTAssertEqual(recorder.logged[1].outputTldr, "Output, Test Subscription, 2")
        XCTAssertEqual(recorder.logged[2].outputTldr, "Output, Test Subscription, 3")

        XCTAssertEqual(recorder.logged[3].type, "Completed")
        XCTAssertEqual(recorder.logged[3].subscription, "Test Subscription")
    }

    /// Test the events emitted by a subject
    func testEmitsEventsFromNonCompletingPublisher() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        let subject = CurrentValueSubject<Int, Never>(0)
        let cancellable = subject
            .lane("Test Subscription", filter: .event, logger: recorder.log)
            .sink(receiveValue: {_ in })

        XCTAssertNotNil(cancellable)
        
        XCTAssertEqual(recorder.logged.count, 1)
        guard recorder.logged.count == 1 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].outputTldr, "Output, Test Subscription, 0")
        
        subject.send(1)
        subject.send(2)
        subject.send(3)

        XCTAssertEqual(recorder.logged.count, 4)
        guard recorder.logged.count == 4 else {
            return
        }
        
        XCTAssertEqual(recorder.logged[1].outputTldr, "Output, Test Subscription, 1")
        XCTAssertEqual(recorder.logged[2].outputTldr, "Output, Test Subscription, 2")
        XCTAssertEqual(recorder.logged[3].outputTldr, "Output, Test Subscription, 3")
    }
    
    /// Test the cancelled event
    func testEmitsEventsFromCancelledPublisher() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        let subject = CurrentValueSubject<Int, Never>(0)
        var cancellable: AnyCancellable? = subject
            .lane("Test Subscription", filter: [.event], logger: recorder.log)
            .sink(receiveValue: {_ in })

        XCTAssertNotNil(cancellable)
        
        XCTAssertEqual(recorder.logged.count, 1)
        guard recorder.logged.count == 1 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].outputTldr, "Output, Test Subscription, 0")
        
        cancellable?.cancel()
        cancellable = nil
        
        // Wait a beat before checking for cancelled event
        let fauxExpectation = expectation(description: "Just waiting a beat")
        DispatchQueue.main.async(execute: fauxExpectation.fulfill)
        wait(for: [fauxExpectation], timeout: 1)
        
        XCTAssertEqual(recorder.logged.count, 2)
        guard recorder.logged.count == 2 else {
            return
        }

        XCTAssertEqual(recorder.logged[1].type, "Cancelled")
    }

    enum TestError: LocalizedError {
        case test
        var errorDescription: String? {
            return "Error description"
        }
    }
    
    /// Test error event
    func testEmitsEventsFromFailedPublisher() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        let subject = CurrentValueSubject<Int, TestError>(0)
        let cancellable = subject
            .lane("Test Subscription", filter: .event, logger: recorder.log)
            .sink(receiveCompletion: { _ in }) { _ in }

        XCTAssertNotNil(cancellable)
        
        XCTAssertEqual(recorder.logged.count, 1)
        guard recorder.logged.count == 1 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].outputTldr, "Output, Test Subscription, 0")
        
        subject.send(completion: .failure(.test))
        
        XCTAssertEqual(recorder.logged.count, 2)
        guard recorder.logged.count == 2 else {
            return
        }

        XCTAssertEqual(recorder.logged[1].type, "Error")
        XCTAssertEqual(recorder.logged[1].value, "Error description")
    }

    /// Test subscription
    func testEmitsSubscription() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        let subject = CurrentValueSubject<Int, TestError>(0)
        let cancellable = subject
            .lane("Test Subscription", filter: .subscription, logger: recorder.log)
            .sink(receiveCompletion: { _ in }) { _ in }

        XCTAssertNotNil(cancellable)
        
        subject.send(1)
        subject.send(2)
        subject.send(3)
        subject.send(completion: .finished)
        
        XCTAssertEqual(recorder.logged.count, 2)
        guard recorder.logged.count == 2 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].signpostType, "begin")
        XCTAssertEqual(recorder.logged[0].subscribe, "Test Subscription")

        XCTAssertEqual(recorder.logged[1].signpostType, "end")
    }

    /// Test formatting
    func testFormatting() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        let subject = CurrentValueSubject<Int, TestError>(0)
        let cancellable = subject
            .lane("Test Subscription", filter: .event, transformValue: { _ in return "TEST" }, logger: recorder.log)
            .sink(receiveCompletion: { _ in }) { _ in }

        XCTAssertNotNil(cancellable)
        
        subject.send(1)
        
        XCTAssertEqual(recorder.logged.count, 2)
        guard recorder.logged.count == 2 else {
            return
        }

        XCTAssertEqual(recorder.logged[1].outputTldr, "Output, Test Subscription, TEST")
    }

    /// Test multiple async subscriptions
    func testMultipleSubscriptions() {
        let recorder = TestLog()
        var subscriptions = [AnyCancellable]()
        
        let initialSubscriptionCount = Timelane.Subscription.subscriptionCounter
        Timelane.Subscription.didEmitVersion = true

        let testPublisher = Publishers.TestPublisher(duration: 1.0)
            .lane("Test Subscription", filter: .event, transformValue: { _ in return "TEST" }, logger: recorder.log)

        testPublisher
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)

        testPublisher
            .sink(receiveCompletion: { _ in }) { _ in }
            .store(in: &subscriptions)
        
        DispatchQueue.global().async {
            testPublisher
                .sink(receiveCompletion: { _ in }) { _ in }
                .store(in: &subscriptions)
        }
        
        // Wait a beat before checking the recorder
        let fauxExpectation = expectation(description: "Just waiting a beat")
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 2) {
            fauxExpectation.fulfill()
        }
        wait(for: [fauxExpectation], timeout: 3)

        XCTAssertEqual(recorder.logged.count, 6)
        guard recorder.logged.count == 6 else {
            return
        }

        XCTAssertEqual(recorder.logged[0].outputTldr, "Output, Test Subscription, TEST")
        XCTAssertEqual(recorder.logged[1].outputTldr, "Output, Test Subscription, TEST")
        XCTAssertEqual(recorder.logged[2].outputTldr, "Output, Test Subscription, TEST")

        XCTAssertEqual(recorder.logged[3].outputTldr, "Completed, Test Subscription, ")
        XCTAssertEqual(recorder.logged[3].id, "\(initialSubscriptionCount+1)")
        XCTAssertEqual(recorder.logged[4].outputTldr, "Completed, Test Subscription, ")
        XCTAssertEqual(recorder.logged[4].id, "\(initialSubscriptionCount+2)")
        XCTAssertEqual(recorder.logged[5].outputTldr, "Completed, Test Subscription, ")
        XCTAssertEqual(recorder.logged[5].id, "\(initialSubscriptionCount+3)")
    }

    /// Test timelane does not affect the subscription events
    func testPasstroughSubscriptionEvents() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true

        var recordedEvents = [String]()
        _ = [1, 2, 3].publisher
            .lane("Test Subscription", filter: .event, transformValue: { _ in return "TEST" }, logger: recorder.log)
            .handleEvents(receiveSubscription: { _ in
                recordedEvents.append("Subscribed")
            }, receiveOutput: { value in
                recordedEvents.append("Value: \(value)")
            }, receiveCompletion: { _ in
                recordedEvents.append("Completed")
            })
            .sink { _ in
                // Nothing to do here
            }
        
        XCTAssertEqual(recordedEvents, [
            "Subscribed",
            "Value: 1",
            "Value: 2",
            "Value: 3",
            "Completed"
        ])
    }

    /// Test the events emitted by a sync array publisher
    func testEmitsAfterReceiveSubscribe() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        var subscriptions = [AnyCancellable]()
        
        [1, 2, 3].publisher
            .lane("Pre Subscription", filter: .event, logger: recorder.log)
            .subscribe(on: DispatchQueue.global())
            .receive(on: RunLoop.main)
            .lane("Post Subscription", filter: .event, logger: recorder.log)
            .sink(receiveValue: {_ in })
            .store(in: &subscriptions)
        
        let fauxExpectation = expectation(description: "Just waiting a beat")
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 2) {
            fauxExpectation.fulfill()
        }
        wait(for: [fauxExpectation], timeout: 3)

        XCTAssertEqual(recorder.logged.count, 8)
        guard recorder.logged.count == 8 else {
            return
        }

        XCTAssertTrue(recorder.logged.map({ $0.outputTldr }).contains("Output, Pre Subscription, 1"))
        XCTAssertTrue(recorder.logged.map({ $0.outputTldr }).contains("Output, Pre Subscription, 2"))
        XCTAssertTrue(recorder.logged.map({ $0.outputTldr }).contains("Output, Pre Subscription, 3"))
        XCTAssertTrue(recorder.logged.map({ $0.outputTldr }).contains("Completed, Pre Subscription, "))

        XCTAssertTrue(recorder.logged.map({ $0.outputTldr }).contains("Output, Post Subscription, 1"))
        XCTAssertTrue(recorder.logged.map({ $0.outputTldr }).contains("Output, Post Subscription, 2"))
        XCTAssertTrue(recorder.logged.map({ $0.outputTldr }).contains("Output, Post Subscription, 3"))
        XCTAssertTrue(recorder.logged.map({ $0.outputTldr }).contains("Completed, Post Subscription, "))
    }

    /// Test the default transformValue behavior.
    func testDefaultTransformValue() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        // Test the default transformValue behavior.
        do {
            let subject = CurrentValueSubject<String, TestError>("")
            let cancellable = subject
                .lane("Test Subscription", filter: .event, logger: recorder.log)
                .sink(receiveCompletion: { _ in }) { _ in }

            XCTAssertNotNil(cancellable)
            
            subject.send("Short Message")
            subject.send("Long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long message.")
            subject.send(completion: .finished)
            
            XCTAssertEqual(recorder.logged.count, 4)
            guard recorder.logged.count == 4 else {
                return
            }
            XCTAssertEqual(recorder.logged[1].value, "Short Message")
            XCTAssertEqual(recorder.logged[2].value, "Long, long, long, long, long, long, long, long, lo...")
        }
    }
    
    func testCustomTransformValue() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        // Test the custom transform behavior
        do {
            let subject = CurrentValueSubject<String, TestError>("")
            let cancellable = subject
                .lane("Test Subscription", filter: .event, transformValue: { $0 }, logger: recorder.log)
                .sink(receiveCompletion: { _ in }) { _ in }

            XCTAssertNotNil(cancellable)
            
            subject.send("Short Message")
            subject.send("Long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long message.")
            subject.send(completion: .finished)
            
            XCTAssertEqual(recorder.logged.count, 4)
            guard recorder.logged.count == 4 else {
                return
            }
            XCTAssertEqual(recorder.logged[1].value, "Short Message")
            XCTAssertEqual(recorder.logged[2].value, "Long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long, long message.")
        }
    }
    
    /// Test timelane does not affect the subscription events
    func testFuture() {
        let recorder = TestLog()
        Timelane.Subscription.didEmitVersion = true
        
        // Test successful future
        do {
            var recordedEvents = [String]()
            var cancellable: Cancellable? = Future<String, Never> { promise in promise(.success("Success")) }
                .lane("Test Subscription", filter: .event, transformValue: { _ in return "TEST" }, logger: recorder.log)
                .handleEvents(receiveSubscription: { _ in
                    recordedEvents.append("Subscribed")
                }, receiveOutput: { value in
                    recordedEvents.append("Value: \(value)")
                }, receiveCompletion: { _ in
                    recordedEvents.append("Completed")
                })
                .sink { _ in }
            
            XCTAssertEqual(recordedEvents, [
                "Subscribed",
                "Value: Success",
                "Completed"
            ])

            _ = cancellable
            cancellable = nil
        }

        // Test error future
        do {
            var recordedEvents = [String]()
            var cancellable: Cancellable? = Future<String, TestError> { promise in promise(.failure(TestError.test)) }
                .lane("Test Subscription", filter: .event, transformValue: { _ in return "TEST" }, logger: recorder.log)
                .handleEvents(receiveSubscription: { _ in
                    recordedEvents.append("Subscribed")
                }, receiveOutput: { value in
                    recordedEvents.append("Value: \(value)")
                }, receiveCompletion: { completion in
                    recordedEvents.append("Completed: \(completion)")
                })
                .sink(receiveCompletion: {_ in }, receiveValue: {_ in })
            
            XCTAssertEqual(recordedEvents, [
                "Subscribed",
                "Completed: failure(TimelaneCombineTests.TimelaneCombineTests.TestError.test)"
            ])

            _ = cancellable
            cancellable = nil
        }
    }
    
    static var allTests = [
        ("testEmitsEventsFromCompletingPublisher", testEmitsEventsFromCompletingPublisher),
        ("testEmitsEventsFromNonCompletingPublisher", testEmitsEventsFromNonCompletingPublisher),
        ("testEmitsEventsFromCancelledPublisher", testEmitsEventsFromCancelledPublisher),
        ("testEmitsEventsFromFailedPublisher", testEmitsEventsFromFailedPublisher),
        ("testEmitsSubscription", testEmitsSubscription),
        ("testFormatting", testFormatting),
        ("testMultipleSubscriptions", testMultipleSubscriptions),
        ("testPasstroughSubscriptionEvents", testPasstroughSubscriptionEvents),
        ("testEmitsAfterReceiveSubscribe", testEmitsAfterReceiveSubscribe),
        ("testDefaultTransformValue", testDefaultTransformValue),
        ("testCustomTransformValue", testCustomTransformValue),
        ("testFuture", testFuture),
    ]
}
