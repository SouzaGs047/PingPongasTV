//
//  GameView.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana.
//  Created by Ruan Lopes Viana.

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
                Color.black.ignoresSafeArea()
                
                if server.sceneSize.width > 0 && server.sceneSize.height > 0 {
                    
                    // Área do Jogo
                    ZStack {
                        let w = server.sceneSize.width
                        let h = server.sceneSize.height
                        
                        // 1. Linha pontilhada do meio
                        ForEach(0..<20) { i in
                            if i % 2 == 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.5))
                                    .frame(width: 4, height: h / 40)
                                    .position(
                                        x: w / 2,
                                        y: (h / 19) * CGFloat(i)
                                    )
                            }
                        }
                        
                        // 2. Placar
                        HStack(spacing: 150) {
                            Text("\(server.scoreLeft)")
                            Text("\(server.scoreRight)")
                        }
                        .font(.system(size: 100, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .position(x: w / 2, y: 100)
                        
                        // 3. Raquete Esquerda
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: server.paddleWidth, height: server.paddleHeight)
                            .position(
                                x: 50 + server.paddleWidth / 2,
                                y: server.paddleLeftY
                            )
                        
                        // 4. Raquete Direita
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: server.paddleWidth, height: server.paddleHeight)
                            .position(
                                x: w - 50 - server.paddleWidth / 2,
                                y: server.paddleRightY
                            )
                        
                        // 5. Bola
                        if server.isGameRunning {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: server.ballSize, height: server.ballSize)
                                .position(server.ballPosition)
                        }
                        
                        // 6. Mensagens de Estado (Esperando Jogadores)
                        if !server.isGameRunning && server.scoreLeft == 0 && server.scoreRight == 0 && !isCountingDown {
                            VStack(spacing: 20) {
                                Text("PONG")
                                    .font(.system(size: 120, weight: .heavy))
                                    .foregroundColor(.white)
                                
                                Text("Aguardando Jogadores...")
                                    .font(.title)
                                    .foregroundColor(.gray)
                                
                                Text("Conecte-se pelo iPhone")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .position(x: w / 2, y: h / 2)
                        }
                        
                        // 7. Countdown
                        if isCountingDown {
                            Text("\(countdown)")
                                .font(.system(size: 200, weight: .heavy))
                                .foregroundColor(.yellow)
                                .shadow(radius: 10)
                                .position(x: w / 2, y: h / 2)
                        }
                    }
                } else {
                    // Tela de Carregamento
                    Text("Inicializando...")
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                if geometry.size.width > 0 {
                    print("📺 Tamanho detectado: \(geometry.size)")
                    server.sceneSize = geometry.size
                    server.start(screenSize: geometry.size)
                    
                    if !hasInitialized {
                        hasInitialized = true
                        startCountdown()
                    }
                }
            }
            .onChange(of: geometry.size) { newSize in
                if newSize.width > 0 && server.sceneSize == .zero {
                    print("📺 Tamanho atualizado: \(newSize)")
                    server.sceneSize = newSize
                    server.start(screenSize: newSize)
                    
                    if !hasInitialized {
                        hasInitialized = true
                        startCountdown()
                    }
                }
            }
            .ignoresSafeArea()
            .onChange(of: server.allPlayersReady) { newValue in
                if newValue == false {
                    server.stopGameLoop()
                    dismiss()
                }
            }
        }
    }
        
        private func startCountdown() {
            countdown = 3
            isCountingDown = true
            server.stopGameLoop()
            
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if countdown > 1 {
                    countdown -= 1
                } else {
                    timer.invalidate()
                    isCountingDown = false
                    server.startGameLoop()
                }
            }
        }
    }
