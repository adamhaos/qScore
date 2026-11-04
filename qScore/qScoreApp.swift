//
//  qScoreApp.swift
//  qScore
//
//  Created by Adam Moore on 9/22/26.
//

import SwiftUI

@main
struct qScoreApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
