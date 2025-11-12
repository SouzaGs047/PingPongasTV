//
//  PingPongas2App.swift
//  PingPongas2
//
//  Created by Gustavo Souza Santana on 11/11/25.
//

import SwiftUI
import SwiftData

@main
struct PingPongasTVApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PlayerModel.self,
            GameModel.self
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
