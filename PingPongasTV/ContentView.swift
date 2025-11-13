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
    
    // Constantes de layout
    let paddleHeight: CGFloat = 100
    let paddleWidth: CGFloat = 20
    let ballSize: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                ForEach(0..<20) { i in
                    if i % 2 == 0 {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 4, height: 20)
                            .position(x: geometry.size.width / 2,
                                      y: (geometry.size.height / 19) * CGFloat(i))
                    }
                }
                
                HStack(spacing: 100) {
                    Text("\(server.scoreLeft)")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(server.scoreRight)")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundColor(.white)
                }
                .position(x: geometry.size.width / 2, y: 70)
                
                // --- Raquete Esquerda
                Rectangle()
                    .fill(Color.white)
                    .frame(width: paddleWidth, height: paddleHeight)
                    .position(x: 50 + (paddleWidth / 2),
                              y: (geometry.size.height / 2) + server.paddleLeftY)
                
                // --- Raquete Direita
                Rectangle()
                    .fill(Color.white)
                    .frame(width: paddleWidth, height: paddleHeight)
                    .position(x: geometry.size.width - 50 - (paddleWidth / 2),
                              y: (geometry.size.height / 2) + server.paddleRightY)
                
                // --- Bola ---
                if server.isGameRunning {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: ballSize, height: ballSize)
                        .position(server.ballPosition)
                }
                
                if !server.isGameRunning && server.scoreLeft == 0 && server.scoreRight == 0 {
                    Text("Esperando jogadores...")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                server.start(screenSize: geometry.size)
            }
        }
    }
}



#Preview {
    ContentView()
}
