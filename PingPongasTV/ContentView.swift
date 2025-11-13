//
//  ContentView.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana on 11/11/25.
//
//  MODIFICADO: Agora é a tela do jogo (View)
//

import SwiftUI

struct ContentView: View {
    @StateObject var server = GameServer()
    
    // Constantes de layout
    let paddleHeight: CGFloat = 100
    let paddleWidth: CGFloat = 20
    let ballSize: CGFloat = 20

    var body: some View {
        // GeometryReader nos dá o tamanho da tela
        GeometryReader { geometry in
            ZStack {
                // Fundo preto
                Color.black.edgesIgnoringSafeArea(.all)
                
                // --- Linha do Meio (Pontilhada) ---
                ForEach(0..<20) { i in
                    if i % 2 == 0 { // Desenha a cada 2
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 4, height: 20)
                            .position(x: geometry.size.width / 2,
                                      y: (geometry.size.height / 19) * CGFloat(i))
                    }
                }

                // --- Placar ---
                HStack(spacing: 100) {
                    Text("\(server.scoreLeft)")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(server.scoreRight)")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.white)
                }
                .position(x: geometry.size.width / 2, y: 70)

                // --- Raquete Esquerda (Jogador 0) ---
                Rectangle()
                    .fill(Color.white)
                    .frame(width: paddleWidth, height: paddleHeight)
                    // `paddleLeftY` é 0 no centro, -Y é para cima, +Y é para baixo
                    .position(x: 50 + (paddleWidth / 2),
                              y: (geometry.size.height / 2) + server.paddleLeftY)
                
                // --- Raquete Direita (Jogador 1) ---
                Rectangle()
                    .fill(Color.white)
                    .frame(width: paddleWidth, height: paddleHeight)
                    .position(x: geometry.size.width - 50 - (paddleWidth / 2),
                              y: (geometry.size.height / 2) + server.paddleRightY)

                // --- Bola ---
                if server.isGameRunning {
                    Rectangle() // Bola quadrada, estilo PONG clássico
                        .fill(Color.white)
                        .frame(width: ballSize, height: ballSize)
                        .position(server.ballPosition)
                }
                
                // --- Mensagem de "Esperando" ---
                if !server.isGameRunning && server.scoreLeft == 0 && server.scoreRight == 0 {
                    Text("Esperando jogadores...")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                // Inicia o servidor e passa o tamanho da tela
                server.start(screenSize: geometry.size)
            }
        }
    }
}



#Preview {
    ContentView()
}
