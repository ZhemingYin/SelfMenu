//
//  SelfMenuApp.swift
//  SelfMenu
//
//  Created by 尹哲铭 on 19.11.25.
//

import SwiftUI
import SwiftData

@main
struct SelfMenuApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MenuItems.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
