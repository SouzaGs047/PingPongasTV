//
//  ContentView.swift
//  PingPongas2
//
//  Created by Gustavo Souza Santana on 11/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var server = GameServer()

    var body: some View {
        VStack {
            Text("Game Server (Apple TV)")
                .font(.largeTitle)

            Button("Enviar teste para todos") {
                server.broadcast(message: "Olá iPhones!")
            }
            .padding()
        }
        .onAppear {
            server.start()
        }
    }
}


#Preview {
    ContentView()
}
