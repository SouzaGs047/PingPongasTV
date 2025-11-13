//
//  GameServer.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana on 11/11/25.
//
//
//

import Foundation
import Network
import Combine
import CoreGraphics

class GameServer: ObservableObject {
    
    // --- Propriedades de Rede ---
    private var listener: NWListener?
    private var isListening = false
    
    private var players: [Int: NWConnection] = [:]
    private let maxPlayers = 2
    
    //  ESTADO DO JOGO
    @Published var paddleLeftY: CGFloat = 0
    @Published var paddleRightY: CGFloat = 0
    @Published var ballPosition: CGPoint = .zero
    @Published var scoreLeft: Int = 0
    @Published var scoreRight: Int = 0
    @Published var isGameRunning = false
    
    //  Propriedades do Jogo
    private var gameTimer: AnyCancellable?
    private var ballVelocity = CGVector(dx: 6, dy: 4)
    private var sceneSize: CGSize = .zero
    private let paddleHeight: CGFloat = 100
    private let paddleWidth: CGFloat = 20
    private let ballSize: CGFloat = 20

    
    func start(screenSize: CGSize) {
        guard !isListening else { return }
        
        self.sceneSize = screenSize
        self.ballPosition = CGPoint(x: screenSize.width / 2, y: screenSize.height / 2)
        self.paddleLeftY = 0
        self.paddleRightY = 0
        self.scoreLeft = 0
        self.scoreRight = 0
        
        isListening = true
        
        print("Iniciando listener...")
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: params)
        } catch {
            print("Erro ao iniciar listener:", error)
            return
        }
        
        listener?.service = NWListener.Service(
            name: "AppleTV-PoC",
            type: "_pocgame._tcp",
            domain: nil,
            txtRecord: nil
        )
        
        listener?.stateUpdateHandler = { state in
            print("Listener mudou:", state)
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            print("Novo iPhone conectado:", connection)
            self?.setupClient(connection)
        }
        
        listener?.start(queue: .main)
        print("Servidor iniciado e anunciado via Bonjour.")
    }
    
    private func setupClient(_ connection: NWConnection) {
        guard players.count < maxPlayers else {
            print("Jogo cheio, rejeitando conexão.")
            connection.cancel()
            return
        }
        
        let playerIndex = players.count
        players[playerIndex] = connection
        
        print("Cliente é Jogador \(playerIndex)")
        
        connection.stateUpdateHandler = { [weak self] state in
            print("Cliente \(playerIndex) mudou: \(state)")
            switch state {
            case .failed(_), .cancelled:
                self?.handleClientDisconnect(connection)
            default:
                break
            }
        }
        
        connection.start(queue: .main)
        receive(connection)

        if players.count == maxPlayers {
            print("2 jogadores conectados → parando listener e iniciando jogo!")
            listener?.cancel()
            listener = nil
            isListening = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startGameLoop()
            }
        }
    }
    
    private func handleClientDisconnect(_ connection: NWConnection) {
        if let playerIndex = players.first(where: { $0.value === connection })?.key {
            print("Jogador \(playerIndex) desconectou.")
            players.removeValue(forKey: playerIndex)
        } else {
            print("Cliente desconectado não era um jogador ativo.")
        }
        
        stopGameLoop()
        
        if !isListening {
            print("Perdemos um jogador → reiniciando listener...")
            start(screenSize: self.sceneSize)
        }
    }
    
    private func receive(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, _, error in
            if let data = data, let str = String(data: data, encoding: .utf8) {
                self?.handlePlayerInput(command: str, from: connection)
            }
            if error == nil {
                self?.receive(connection)
            } else {
                self?.handleClientDisconnect(connection)
            }
        }
    }
    
    private func handlePlayerInput(command: String, from connection: NWConnection) {
        guard let playerIndex = players.first(where: { $0.value === connection })?.key else { return }
        
        let moveAmount: CGFloat = 25.0
        let halfPaddle = paddleHeight / 2
        
        let topBound = -(sceneSize.height / 2) + halfPaddle
        let bottomBound = (sceneSize.height / 2) - halfPaddle
        
        DispatchQueue.main.async {
            if playerIndex == 0 {
                var newY = self.paddleLeftY
                if command == "up" {
                    newY -= moveAmount
                } else if command == "down" {
                    newY += moveAmount
                }
                self.paddleLeftY = min(max(newY, topBound), bottomBound)
                
            } else if playerIndex == 1 {
                var newY = self.paddleRightY
                if command == "up" {
                    newY -= moveAmount
                } else if command == "down" {
                    newY += moveAmount
                }
                self.paddleRightY = min(max(newY, topBound), bottomBound)
            }
        }
    }
    
    func startGameLoop() {
        guard !isGameRunning else { return }
        
        isGameRunning = true
        self.gameTimer = Timer.publish(every: 1/60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateGame()
            }
    }
    
    func stopGameLoop() {
        isGameRunning = false
        gameTimer?.cancel()
        gameTimer = nil
    }
    
    private func updateGame() {
        guard isGameRunning, sceneSize != .zero else { return }
        
        ballPosition.x += ballVelocity.dx
        ballPosition.y += ballVelocity.dy

        let ballRadius = ballSize / 2
        
        if ballPosition.y <= ballRadius || ballPosition.y >= (sceneSize.height - ballRadius) {
            ballVelocity.dy *= -1
        }
        
        let leftPaddleCenterY = paddleLeftY + (sceneSize.height / 2)
        let rightPaddleCenterY = paddleRightY + (sceneSize.height / 2)

        let paddleLeftRect = CGRect(x: 50, y: leftPaddleCenterY - (paddleHeight/2), width: paddleWidth, height: paddleHeight)
        if ballPosition.x <= (paddleLeftRect.maxX + ballRadius) && paddleLeftRect.contains(ballPosition) {
            ballVelocity.dx *= -1
        }
        
        let paddleRightRect = CGRect(x: sceneSize.width - 50 - paddleWidth, y: rightPaddleCenterY - (paddleHeight/2), width: paddleWidth, height: paddleHeight)
        if ballPosition.x >= (paddleRightRect.minX - ballRadius) && paddleRightRect.contains(ballPosition) {
            ballVelocity.dx *= -1
        }
        
        if ballPosition.x > sceneSize.width {
            scoreLeft += 1
            resetBall(direction: -1)
        }
        
        if ballPosition.x < 0 {
            scoreRight += 1
            resetBall(direction: 1)
        }
    }
    
    private func resetBall(direction: Int) {
        stopGameLoop()
        
        ballPosition = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        ballVelocity.dx = 6 * CGFloat(direction)
        ballVelocity.dy = [4, -4, 3, -3].randomElement() ?? 4
        
        paddleLeftY = 0
        paddleRightY = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startGameLoop()
        }
    }
    
    func broadcast(message: String) {
        let data = message.data(using: .utf8)!
        for (_, client) in players {
            client.send(content: data, completion: NWConnection.SendCompletion.contentProcessed { _ in })
        }
    }
}
