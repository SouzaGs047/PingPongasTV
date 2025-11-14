//
//  ContentView.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana on 11/11/25.
//
//
//

import SwiftUI

struct ContentView: View {
    @StateObject var server = GameServer()
    @State private var startGame = false   // ← controla a navegação

    var body: some View {
        NavigationStack {
            VStack {
                GeometryReader { geometry in
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
                        server.start(screenSize: geometry.size)
                    }
                }
            }
            .navigationDestination(isPresented: $startGame) {
                GameView(server: server)     // ← tela do jogo
            }
            .onAppear {
                startGame = false
            }
            .onChange(of: server.allPlayersReady) {
                if server.allPlayersReady {
                    print("🚀 Todos prontos! Iniciando o jogo…")
                    startGame = true
                }
            }
        }
    }
}




#Preview {
    ContentView()
}
