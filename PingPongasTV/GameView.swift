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
            let squareSide = min(geometry.size.width, geometry.size.height)

            ZStack {
                Color.black.ignoresSafeArea()

                // Quadrado do Pong
                ZStack {
                    let w = server.sceneSize.width
                    let h = server.sceneSize.height

                    ZStack {
                        // Linha pontilhada do meio
                        ForEach(0..<20) { i in
                            if i % 2 == 0 {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 20)
                                    .position(
                                        x: w / 2,
                                        y: (h / 19) * CGFloat(i)
                                    )
                            }
                        }

                        // Placar
                        HStack(spacing: 100) {
                            Text("\(server.scoreLeft)")
                                .font(.system(size: 80, weight: .bold))
                                .foregroundColor(.white)
                            Text("\(server.scoreRight)")
                                .font(.system(size: 80, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .position(x: w / 2, y: 60)

                        // Raquete esquerda
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: server.paddleWidth,
                                   height: server.paddleHeight)
                            .position(
                                x: 50 + server.paddleWidth / 2,
                                y: server.paddleLeftY
                            )

                        // Raquete direita  👉 AGORA usando w, não geometry.size.width
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: server.paddleWidth,
                                   height: server.paddleHeight)
                            .position(
                                x: w - 50 - server.paddleWidth / 2,
                                y: server.paddleRightY
                            )

                        // Bola
                        if server.isGameRunning {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: server.ballSize, height: server.ballSize)
                                .position(server.ballPosition)
                        }

                        // Mensagens e countdown (use w/h também)
                        if !server.isGameRunning &&
                            server.scoreLeft == 0 &&
                            server.scoreRight == 0 &&
                            !isCountingDown {

                            Text("Esperando jogadores...")
                                .font(.title)
                                .foregroundColor(.white)
                                .position(x: w / 2, y: h / 2)
                        }

                        if isCountingDown {
                            Text("\(countdown)")
                                .font(.system(size: 120, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                                .position(x: w / 2, y: h / 2)
                        }
                    }
                }
                .frame(width: squareSide, height: squareSide)
                .position(x: geometry.size.width / 2.2,
                          y: geometry.size.height / 2)
            }
            .onAppear {
                if !hasInitialized {
                    hasInitialized = true
                    let playfieldSize = CGSize(width: squareSide, height: squareSide)
                    server.start(screenSize: playfieldSize)
                    startCountdown()
                }
            }
        }
        .onChange(of: server.allPlayersReady) { newValue in
            if newValue == false {
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
