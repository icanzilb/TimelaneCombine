//
// Copyright(c) Marin Todorov 2020
// For the license agreement for this code check the LICENSE file.
//

import Foundation
import Combine
import TimelaneCore

extension Publishers {
    /// A publisher that logs the current subscription and its events to Timelane running in Instruments.
    public class TimelanePublisher<Upstream: Publisher>: Publisher {
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        
        private let name: String?
        private let filter: Timelane.LaneTypeOptions
        private let source: String
        private let transformValue: (Upstream.Output) -> String
        private let logger: Timelane.Logger

        /// Creates a new Timelane publisher.
        /// - Parameters:
        ///   - upstream: The event stream to subscribe.
        ///   - name: The name to use when logging events from this subscription.
        ///   - filter: A filter to log only subscription, events, or both.
        ///   - source: The source to include along logged events.
        ///   - transformValue: A closure that formats values before logging.
        ///   - value: The subscription output value to format for logging.
        ///   - logger: The logger to use for this subscription.
        public init(upstream: Upstream,
                    name: String?,
                    filter: Timelane.LaneTypeOptions,
                    source: String,
                    transformValue: @escaping (Upstream.Output) -> String,
                    logger: @escaping Timelane.Logger) {
            self.upstream = upstream
            self.name = name
            self.filter = filter
            self.source = source
            self.transformValue = transformValue
            self.logger = logger
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            let filter = self.filter
            let source = self.source
            let subscription = Timelane.Subscription(name: name, logger: logger)
            let transform = self.transformValue
            
            let sink = AnySubscriber<Upstream.Output, Upstream.Failure>(
                receiveSubscription: { sub in
                    if filter.contains(.subscription) {
                        subscription.begin(source: source)
                    }
                    
                    subscriber.receive(subscription: sub)
                },
                receiveValue: { value -> Subscribers.Demand in
                    if filter.contains(.event) {
                        subscription.event(value: .value(transform(value)), source: source)
                    }

                    return subscriber.receive(value)
                },
                receiveCompletion: { completion in
                    if filter.contains(.subscription) {
                        switch completion {
                        case .finished:
                            subscription.end(state: .completed)
                        case .failure(let error):
                            subscription.end(state: .error(error.localizedDescription))
                        }
                    }
                    
                    if filter.contains(.event) {
                        switch completion {
                        case .finished:
                            subscription.event(value: .completion, source: source)
                        case .failure(let error):
                            subscription.event(value: .error(error.localizedDescription), source: source)
                        }
                    }
                    
                    subscriber.receive(completion: completion)
                }
            )
            
            upstream
                .handleEvents(receiveCancel: {
                    // Sometimes a "cancel" event preceeds "finished" so we seem to
                    // need this hack below to make sure "finished" goes out first.
                    DispatchQueue.main.async {
                        // Cancelling the subscription
                        if filter.contains(.subscription) {
                            subscription.end(state: .cancelled)
                        }
                        if filter.contains(.event) {
                            subscription.event(value: .cancelled, source: source)
                        }
                    }
                })
                .subscribe(sink)
        }
    }
}

extension Publisher {
    
    /// The `lane` operator logs a subscription and its events to the Timelane Instrument.
    ///
    ///  - Note: You can download the Timelane Instrument from http://timelane.tools
    /// - Parameters:
    ///   - name: A name for the lane when visualized in Instruments
    ///   - filter: Which events to log subscriptions or data events.
    ///             For example for a subscription on a subject you might be interested only in data events.
    ///   - file: If not specified, contains the file name where the operator is called.
    ///   - function: If not specified, by default contains the method name where the operator is called.
    ///   - line: If not specified, by default contains the source file line where the operator is called.
    ///   - transformValue: An optional closure to format emitted subscription values for logging.
    ///                     You can not only prettify the values but also change them completely, e.g. for arrays you can
    ///                     it might be more useful to report the count of elements if there are a lot of them.
    ///                     If `nil`, the default behavior is to generate a plain text description of the value
    ///                     and cap it to `50` characters.
    ///   - value: The value emitted by the subscription
    ///   - logger: The logger to use for this subscription.
    public func lane(_ name: String,
                     filter: Timelane.LaneTypeOptions = .all,
                     file: StaticString = #file,
                     function: StaticString  = #function, line: UInt = #line,
                     transformValue: ((Output) -> String)? = nil,
                     logger: @escaping Timelane.Logger = Timelane.defaultLogger)
        -> Publishers.TimelanePublisher<Self> {

        let fileName = file.description.components(separatedBy: "/").last!
        let source = "\(fileName):\(line) - \(function)"
        
        let transformer = transformValue ??
            { String(describing: $0).appendingEllipsis(after: 50) }
        
        return Publishers.TimelanePublisher(upstream: self,
                                            name: name,
                                            filter: filter,
                                            source: source,
                                            transformValue: transformer,
                                            logger: logger)
    }
}

fileprivate extension String {
    func appendingEllipsis(after: Int) -> String {
        guard count > after else { return self }
        return prefix(after).appending("...")
    }
}
