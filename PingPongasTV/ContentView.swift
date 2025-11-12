//
//  ContentView.swift
//  PingPongasTV
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

            HStack {
                VStack {
                    Text("Lado Esquerdo")
                        .font(.headline)
                    ForEach(server.game.sideL, id: \.name) { player in
                        Text(player.name)
                    }
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("Lado Direito")
                        .font(.headline)
                    ForEach(server.game.sideR, id: \.name) { player in
                        Text(player.name)
                    }
                }
                .frame(maxWidth: .infinity)
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
