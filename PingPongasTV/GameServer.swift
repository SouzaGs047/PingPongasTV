//
//  GameServer.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana.
//  Created by Ruan Lopes Viana.

import Foundation
import Network
import Combine
import CoreGraphics

class GameServer: ObservableObject {
    
    // MARK: - Propriedades de Rede
    private var listener: NWListener?
    private var isListening = false
    private let maxPlayers = 2
    
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    
    private struct PlayerConnectionInfo {
        var player: PlayerModel
        var side: String
        var connection: NWConnection
    }
    private var playerInfos: [ObjectIdentifier: PlayerConnectionInfo] = [:]
    
    // MARK: - Estado do Jogo (Publicado para a View)
    
    @Published var game = GameModel(sideL: [], scoreL: 0, sideR: [], scoreR: 0)
    @Published var allPlayersReady: Bool = false
    @Published var isGameRunning = false
    
    // Posições Visuais
    @Published var paddleLeftY: CGFloat = 0
    @Published var paddleRightY: CGFloat = 0
    @Published var ballPosition: CGPoint = .zero
    @Published var scoreLeft: Int = 0
    @Published var scoreRight: Int = 0
    
    // MARK: - Configurações Físicas
    
    private var gameTimer: AnyCancellable?
    private var ballVelocity = CGVector(dx: 0, dy: 0)
    
    // Tamanho da tela (será preenchido pela View)
    @Published var sceneSize: CGSize = .zero
    
    // Dimensões dos objetos
    let paddleHeight: CGFloat = 200
    let paddleWidth: CGFloat = 30
    let ballSize: CGFloat = 40
    
    // MARK: - Inicialização do Servidor
    
    func start(screenSize: CGSize) {
        guard !isListening else { return }
        
        self.sceneSize = screenSize
        resetPositions()
        
        isListening = true
        print("📡 Iniciando servidor Pong...")
        
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        
        do {
            listener = try NWListener(using: params)
        } catch {
            print("❌ Erro ao iniciar listener:", error)
            return
        }
        
        // Configuração do Bonjour (para o iPhone encontrar)
        listener?.service = NWListener.Service(
            name: "AppleTV-Pong",
            type: "_pocgame._tcp",
            domain: nil,
            txtRecord: nil
        )
        
        listener?.stateUpdateHandler = { state in
            print("📡 Estado do Listener:", state)
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            print("📱 Nova conexão recebida:", connection)
            self?.setupClient(connection)
        }
        
        listener?.start(queue: .main)
    }
    
    private func resetPositions() {
        self.ballPosition = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        self.paddleLeftY = sceneSize.height / 2
        self.paddleRightY = sceneSize.height / 2
    }
    
    // MARK: - Gerenciamento de Clientes
    
    private func setupClient(_ connection: NWConnection) {
        guard connections.count < maxPlayers else {
            print("⛔ Jogo cheio. Rejeitando conexão.")
            connection.cancel()
            return
        }
        
        let id = ObjectIdentifier(connection)
        connections[id] = connection
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                print("❌ Erro na conexão cliente:", error)
                self?.handleClientDisconnect(connection)
            case .cancelled:
                print("🚪 Cliente desconectou.")
                self?.handleClientDisconnect(connection)
            default:
                break
            }
        }
        
        connection.start(queue: .main)
        receive(from: connection)
    }
    
    private func handleClientDisconnect(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        
        // Remove dados do jogador
        if let info = playerInfos[id] {
            print("👤 Jogador saiu: \(info.player.name)")
            removePlayerFromGameModel(name: info.player.name)
            playerInfos.removeValue(forKey: id)
        }
        
        connections.removeValue(forKey: id)
        connection.cancel()
        
        // Reseta estado de prontidão
        resetAllPlayersReady()
        stopGameLoop()
        
        // Se ficar vazio, reinicia posições
        if connections.isEmpty {
            resetPositions()
            scoreLeft = 0
            scoreRight = 0
        }
    }
    
    private func receive(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, error in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                self?.processMessage(message, from: connection)
            }
            
            if error == nil {
                self?.receive(from: connection)
            } else {
                self?.handleClientDisconnect(connection)
            }
        }
    }
    
    // MARK: - Processamento de Mensagens
    
    private func processMessage(_ message: String, from connection: NWConnection) {
        if message == "up" || message == "down" {
            handleGameplayInput(command: message, from: connection)
            return
        }
        
        // Comandos de protocolo (JOIN, READY, etc)
        let parts = message.split(separator: ":").map(String.init)
        guard !parts.isEmpty else { return }
        
        let command = parts[0]
        let id = ObjectIdentifier(connection)
        
        switch command {
        case "JOIN":
            // Formato: JOIN:side:name
            if parts.count >= 3 {
                let side = parts[1]
                let name = parts[2]
                let newPlayer = PlayerModel(name: name)
                
                // Salva infos
                let info = PlayerConnectionInfo(player: newPlayer, side: side, connection: connection)
                playerInfos[id] = info
                
                // Atualiza Model visual
                if side == "left" { game.sideL.append(newPlayer) }
                else { game.sideR.append(newPlayer) }
                
                print("✅ \(name) entrou no time \(side)")
            }
            
        case "READY":
            // Formato: READY:1 ou READY:0
            if parts.count >= 2, var info = playerInfos[id] {
                let isReady = (parts[1] == "1")
                info.player.isReady = isReady
                playerInfos[id] = info
                
                print("⚠️ \(info.player.name) está pronto? \(isReady)")
                checkAllPlayersReady()
            }
            
        default:
            break
        }
    }
    
    private func handleGameplayInput(command: String, from connection: NWConnection) {
        guard let info = playerInfos[ObjectIdentifier(connection)] else { return }
        
        let speed: CGFloat = 35.0
        let halfPaddle = paddleHeight / 2
        let maxY = sceneSize.height - halfPaddle
        let minY = halfPaddle
        
        DispatchQueue.main.async {
            if info.side == "left" {
                var y = self.paddleLeftY
                if command == "up" { y -= speed }
                if command == "down" { y += speed }
                self.paddleLeftY = min(max(y, minY), maxY)
            } else {
                var y = self.paddleRightY
                if command == "up" { y -= speed }
                if command == "down" { y += speed }
                self.paddleRightY = min(max(y, minY), maxY)
            }
        }
    }
    
    // MARK: - Lógica de Jogo (Game Loop)
    
    func startGameLoop() {
        guard !isGameRunning else { return }
        print("🚀 Iniciando Loop do Jogo")
        
        isGameRunning = true
        
        // Define velocidade inicial (para a direita ou esquerda aleatoriamente)
        let startDir: CGFloat = Bool.random() ? 1 : -1
        resetBallPhysics(direction: startDir)
        
        // Timer de 60 FPS
        gameTimer = Timer.publish(every: 1/60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePhysics()
            }
    }
    
    func stopGameLoop() {
        isGameRunning = false
        gameTimer?.cancel()
        gameTimer = nil
    }
    
    private func updatePhysics() {
        guard isGameRunning, sceneSize.width > 0 else { return }
        
        // 1. Aplica velocidade
        ballPosition.x += ballVelocity.dx
        ballPosition.y += ballVelocity.dy
        
        let r = ballSize / 2
        
        // 2. Colisão Teto/Chão
        if ballPosition.y <= r {
            ballPosition.y = r + 1
            ballVelocity.dy *= -1
        } else if ballPosition.y >= sceneSize.height - r {
            ballPosition.y = sceneSize.height - r - 1
            ballVelocity.dy *= -1
        }
        
        // 3. Define Rects para Colisão
        let ballRect = CGRect(x: ballPosition.x - r, y: ballPosition.y - r, width: ballSize, height: ballSize)
        
        let pLeftRect = CGRect(x: 50, y: paddleLeftY - paddleHeight/2, width: paddleWidth, height: paddleHeight)
        let pRightRect = CGRect(x: sceneSize.width - 50 - paddleWidth, y: paddleRightY - paddleHeight/2, width: paddleWidth, height: paddleHeight)
        
        // 4. Colisão Raquete Esquerda
        if ballRect.intersects(pLeftRect) && ballVelocity.dx < 0 {
            ballVelocity.dx *= -1.05
            ballVelocity.dy *= 1.05
            ballPosition.x = pLeftRect.maxX + r + 2
        }
        
        // 5. Colisão Raquete Direita
        if ballRect.intersects(pRightRect) && ballVelocity.dx > 0 {
            ballVelocity.dx *= -1.05
            ballVelocity.dy *= 1.05
            ballPosition.x = pRightRect.minX - r - 2
        }
        
        // 6. Pontuação (Bola saiu da tela)
        if ballPosition.x < -r {
            scoreRight += 1
            handleScore(winnerSide: "right")
        } else if ballPosition.x > sceneSize.width + r {
            scoreLeft += 1
            handleScore(winnerSide: "left")
        }
    }
    
    private func handleScore(winnerSide: String) {
        stopGameLoop()
        
        // Reinicia a bola no centro
        ballPosition = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        
        // A bola vai na direção de quem sofreu o ponto
        let nextDir: CGFloat = (winnerSide == "left") ? 1 : -1
        
        // Pequena pausa antes de recomeçar
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.allPlayersReady {
                self.isGameRunning = true
                self.resetBallPhysics(direction: nextDir)
                
                // Recria o timer
                self.gameTimer = Timer.publish(every: 1/60, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in self?.updatePhysics() }
            }
        }
    }
    
    private func resetBallPhysics(direction: CGFloat) {
        let baseSpeed: CGFloat = 9.0
        ballVelocity = CGVector(dx: baseSpeed * direction, dy: CGFloat.random(in: -5...5))
    }
    
    // MARK: - Métodos Auxiliares
    
    private func removePlayerFromGameModel(name: String) {
        game.sideL.removeAll { $0.name == name }
        game.sideR.removeAll { $0.name == name }
    }
    
    private func checkAllPlayersReady() {
        let readyCount = playerInfos.values.filter { $0.player.isReady }.count
        let allReady = (readyCount == 2)
        
        if allPlayersReady != allReady {
            allPlayersReady = allReady
            if allReady {
                broadcast("START")
            } else {
                broadcast("STOP")
            }
        }
    }
    
    private func resetAllPlayersReady() {
        for id in playerInfos.keys {
            playerInfos[id]?.player.isReady = false
        }
        checkAllPlayersReady()
    }
    
    func broadcast(_ message: String) {
        let data = message.data(using: .utf8)!
        for conn in connections.values {
            conn.send(content: data, completion: NWConnection.SendCompletion.contentProcessed { _ in })
        }
    }
}
