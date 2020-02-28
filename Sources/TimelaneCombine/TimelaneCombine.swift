//
// Copyright(c) Marin Todorov 2020
// For the license agreement for this code check the LICENSE file.
//

import Foundation
import Combine
import TimelaneCore

extension Publishers {
    public class TimelanePublisher<Upstream: Publisher>: Publisher {
        public enum LaneType: Int, CaseIterable {
            case subscription, event
        }
        
        public typealias Output = Upstream.Output
        public typealias Failure = Upstream.Failure
        
        private let upstream: Upstream
        
        private let subscription: Timelane.Subscription
        private let filter: Set<LaneType>
        private let source: String
        private let transformValue: (Upstream.Output) -> String
        
        public init(upstream: Upstream,
                    name: String?,
                    filter: Set<LaneType>,
                    source: String,
                    transformValue: @escaping (Upstream.Output) -> String) {
            self.upstream = upstream
            self.filter = filter
            self.source = source
            self.subscription = Timelane.Subscription(name: name)
            self.transformValue = transformValue
        }
        
        public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
            let filter = self.filter
            let source = self.source
            let subscription = self.subscription
            
            let sink = AnySubscriber<Upstream.Output, Upstream.Failure>(
                receiveSubscription: { [weak self] sub in
                    guard let self = self else { return }
                    
                    if self.filter.contains(.subscription) {
                        subscription.begin(source: self.source)
                    }
                    
                    subscriber.receive(subscription: sub)
                },
                receiveValue: { [weak self] value -> Subscribers.Demand in
                    guard let transform = self?.transformValue else { return .none }

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
                    // Cancelling the subscription
                    if filter.contains(.subscription) {
                        subscription.end(state: .cancelled)
                    }
                    if filter.contains(.event) {
                        subscription.event(value: .cancelled, source: source)
                    }
                })
                .subscribe(sink)
        }
    }
}

extension Publisher {
    public func lane(_ name: String,
                     filter: Set<Publishers.TimelanePublisher<Self>.LaneType> = Set(Publishers.TimelanePublisher.LaneType.allCases),
                     file: StaticString = #file,
                     function: StaticString  = #function, line: UInt = #line,
                     transformValue: @escaping (Output) -> String = { String(describing: $0) })
        -> Publishers.TimelanePublisher<Self> {
        let fileName = file.description.components(separatedBy: "/").last!
        let source = "\(fileName):\(line) - \(function)"
        
        return Publishers.TimelanePublisher(upstream: self,
                                            name: name,
                                            filter: filter,
                                            source: source,
                                            transformValue: transformValue)
    }
}
