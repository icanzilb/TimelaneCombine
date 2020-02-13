# Timelane + Combine

![Timelane Icon](etc/Icon_128x128@2x.png)

**TimelaneCombine** provides a Combine bindings for profiling Combine code with the Timelane Instrument.

![Timelane Instrument](etc/timelane.png)

Contents:

1. [Usage](#Usage)
2. [Reference](#Reference)
3. [Installation](#Installation)
4. [Demo](#Demo)
5. [Todo](#Todo)
6. [License](#License)

# Usage

Import the TimelaneCombine framework in your code:

```swift
import TimelaneCombine
```

Use the `lane(_)` operator to profile a subscription via the TimelaneInstrument. Insert `lane(_)` at the precise spot in your code you'd like to profile like so:

```swift
downloadImage(at: url).
  .lane("Download: \(url.path)")
  .assign(to: \.image, on: myImageView)
```

Then profile your project by clicking **Product > Profile** in Xcode's main menu.

Select the Timelane Instrument template:

![Timelane Instrument Template](etc/timelane-template.png)

Inspect your subscriptions on the timeline:

![Timelane Live Recording](etc/timelane-recording.gif)

For a more detailed walkthrough go to [http://timelane.tools](http://timelane.tools).

# Reference

## `lane(_:filter:)`

Use `lane("Lane name")` to send data to both the subscriptions and events lanes in the Timelane Instrument.

`lane("Lane name", filter: [.subscriptions])` sends begin/completion events to the Subscriptions lane. Use this syntax if you only want to observe concurrent subscriptions.

`lane("Lane name", filter: [.events])` sends events and values to the Events lane. Use this filter if you are only interested in values a subscription would emit (e.g. for example subjects).

# Installation

## Swift Package Manager

I . Automatically in Xcode:

 - Click **File > Swift Packages > Add Package Dependency...**  
 - Use the package URL `https://github.com/icanzilb/TimelaneCombine` to add TimelaneCombine to your project.

II . Manually in your **Package.swift** file add:

```swift
.package(url: "https://github.com/icanzilb/TimelaneCombine", .from("0.9.0"))
```

# Demo

The Timelane package contains a demo app at: https://github.com/icanzilb/timelane.

# Todo

- [ ] CocoaPods
- [ ] Carthage

# License

Copyright (c) Marin Todorov 2020
This package is provided under the MIT License.