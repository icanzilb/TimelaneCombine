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
            .lane("Test Subscription", filter: [.event], logger: recorder.log)
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
            .lane("Test Subscription", filter: [.event], logger: recorder.log)
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
            .lane("Test Subscription", filter: [.event], logger: recorder.log)
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
            .lane("Test Subscription", filter: [.subscription], logger: recorder.log)
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
            .lane("Test Subscription", filter: [.event], transformValue: { _ in return "TEST" }, logger: recorder.log)
            .sink(receiveCompletion: { _ in }) { _ in }

        XCTAssertNotNil(cancellable)
        
        subject.send(1)
        
        XCTAssertEqual(recorder.logged.count, 2)
        guard recorder.logged.count == 2 else {
            return
        }

        XCTAssertEqual(recorder.logged[1].outputTldr, "Output, Test Subscription, TEST")
    }
    
    static var allTests = [
        ("testEmitsEventsFromCompletingPublisher", testEmitsEventsFromCompletingPublisher),
        ("testEmitsEventsFromNonCompletingPublisher", testEmitsEventsFromNonCompletingPublisher),
        ("testEmitsEventsFromCancelledPublisher", testEmitsEventsFromCancelledPublisher),
        ("testEmitsEventsFromFailedPublisher", testEmitsEventsFromFailedPublisher),
        ("testEmitsSubscription", testEmitsSubscription),
        ("testFormatting", testFormatting),
    ]
}
