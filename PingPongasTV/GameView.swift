//
//  GameView.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana on 13/11/25.
//
import SwiftUI

struct GameView: View {
    @ObservedObject var server: GameServer
    @Environment(\.dismiss) var dismiss
    
    @State private var hasInitialized = false
    @State private var countdown = 3
    @State private var isCountingDown = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fundo preto
                Color.black.edgesIgnoringSafeArea(.all)
                
                // --- Linha do Meio (Pontilhada) ---
                ForEach(0..<20) { i in
                    if i % 2 == 0 {
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
                
                // --- Raquete Esquerda ---
                Rectangle()
                    .fill(Color.white)
                    .frame(width: server.paddleWidth, height: server.paddleHeight)
                    .position(x: 50 + (server.paddleWidth / 2),
                              y: (geometry.size.height / 2) + server.paddleLeftY)
                
                // --- Raquete Direita ---
                Rectangle()
                    .fill(Color.white)
                    .frame(width: server.paddleWidth, height: server.paddleHeight)
                    .position(x: geometry.size.width - 50 - (server.paddleWidth / 2),
                              y: (geometry.size.height / 2) + server.paddleRightY)
                
                // --- Bola ---
                if server.isGameRunning {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: server.ballSize, height: server.ballSize)
                        .position(server.ballPosition)
                }
                
                // --- Mensagem de "Esperando" (antes de qualquer jogo) ---
                if !server.isGameRunning && server.scoreLeft == 0 && server.scoreRight == 0 && !isCountingDown {
                    Text("Esperando jogadores...")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
                
                // --- Contagem regressiva ---
                if isCountingDown {
                    Text("\(countdown)")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(radius: 10)
                }
            }
            .onAppear {
                // Garante que só inicializa uma vez
                if !hasInitialized {
                    hasInitialized = true
                    
                    // Inicializa o servidor com o tamanho da tela
                    server.start(screenSize: geometry.size)
                    
                    // Começa a contagem de 3 segundos
                    startCountdown()
                }
            }
        }
        .onChange(of: server.allPlayersReady) {
            if !server.allPlayersReady {
                // Se alguém deixou de estar pronto → para o jogo e volta
                server.stopGameLoop()
                dismiss()
            }
        }
    }
    
    private func startCountdown() {
        countdown = 3
        isCountingDown = true
        
        // Garante que o jogo não esteja rodando enquanto conta
        server.stopGameLoop()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 1 {
                countdown -= 1
            } else {
                timer.invalidate()
                isCountingDown = false
                // Agora sim começa o jogo
                server.startGameLoop()
            }
        }
    }
}
