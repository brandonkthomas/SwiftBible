//
//  AppEnvironment.swift
//  HomePlus
//
//  Created by Brandon Thomas on 6/27/26.
//

import Observation

/// App-wide owner of our single repository
@Observable
final class AppEnvironment {

    // MARK: Properties

    let readerStore: ReaderStore

    // MARK: Init

    init() {
        let repository = FakeBibleRepository() // TODO
        self.readerStore = ReaderStore(repository: repository)
    }
}
