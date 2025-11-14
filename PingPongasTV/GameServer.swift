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
    private var listener: NWListener?
    private var isListening = false
    
    private var players: [Int: NWConnection] = [:]
    private let maxPlayers = 2
    @Published var game = GameModel(sideL: [], scoreL: 0, sideR: [], scoreR: 0)
    private var connectionToPlayer: [ObjectIdentifier: (player: PlayerModel, side: String)] = [:]
        
    @Published var allPlayersReady: Bool = false

    // --- ESTADO DO JOGO (Para a View) ---
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
    let paddleHeight: CGFloat = 100
    let paddleWidth: CGFloat = 20
    let ballSize: CGFloat = 20

    
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
            DispatchQueue.main.async {
                print("Cliente \(playerIndex) mudou: \(state)")
                switch state {
                case .failed(let error):
                    print("❌ Falha no cliente \(playerIndex): \(error)")
                    self?.handleClientDisconnect(connection)
                case .cancelled:
                    print("🚪 Cliente \(playerIndex) desconectou.")
                    self?.handleClientDisconnect(connection)
                default:
                    break
                }
            }
        }

        
        connection.start(queue: .main)
        receive(connection)

        if players.count == maxPlayers {
            print("2 jogadores conectados → parando listener e iniciando jogo!")
            listener?.cancel()
            listener = nil
            isListening = false
        }
    }
    
    private func handleClientDisconnect(_ connection: NWConnection) {
        connection.cancel()
        connection.stateUpdateHandler = nil
        
        // Encontrar playerIndex
        if let playerIndex = players.first(where: { $0.value === connection })?.key {
            print("Jogador \(playerIndex) desconectou.")
            players.removeValue(forKey: playerIndex)
        }
        
        // --- Remover do mapeamento de readiness ---
        let id = ObjectIdentifier(connection)
        if let info = connectionToPlayer[id] {
            removePlayer(info.player, from: info.side)
            connectionToPlayer.removeValue(forKey: id)
        }
        
        // --- ATUALIZAR READINESS (zera todo mundo) ---
        resetAllPlayersReady()

        stopGameLoop()

        if !isListening {
            print("Perdemos um jogador → reiniciando listener...")
            start(screenSize: self.sceneSize)
        }
    }



    
    private func receive(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, _, error in
            if let data = data, let str = String(data: data, encoding: .utf8) {
                self?.handleMessage(str, from: connection)
                self?.handlePlayerInput(command: str, from: connection)
            }
            if let error = error {
                print("⚠️ Erro na conexão: \(error)")
                self?.handleClientDisconnect(connection)
            } else {
                self?.receive(connection)
            }
        }
    }
    
    private func handleMessage(_ message: String, from connection: NWConnection) {
            print("Recebido:", message)
            let parts = message.split(separator: ":")
            guard parts.count >= 2 else { return }
            
            let command = parts[0]
            let id = ObjectIdentifier(connection)
            
            switch command {
            case "JOIN":
                if parts.count == 3 {
                    let side = String(parts[1])
                    let name = String(parts[2])
                    let player = PlayerModel(name: name)
                    
                    if side == "left" {
                        game.sideL.append(player)
                    } else if side == "right" {
                        game.sideR.append(player)
                    }
                    connectionToPlayer[id] = (player, side)
                    print("Jogador \(name) entrou no lado \(side)")
                }
                
            case "LEAVE":
                if parts.count == 2 {
                    let name = String(parts[1])

                    print("Jogador \(name) saiu manualmente")

                    // Remove o jogador das listas de lados
                    removePlayerByName(name)

                    // Remove do mapa de conexões
                    connectionToPlayer = connectionToPlayer.filter { $0.value.player.name != name }

                    // Zera o READY de todos que sobraram
                    resetAllPlayersReady()
                }

            case "READY":
                if parts.count == 2 {
                    let readyFlag = String(parts[1]) == "1"
                    
                    if let info = connectionToPlayer[id] {
                        let playerName = info.player.name
                        info.player.isReady = readyFlag
                        connectionToPlayer[id] = info
                        
                        print("Jogador \(playerName) está \(readyFlag ? "pronto ✅" : "não pronto ❌")")
                    } else {
                        print("⚠️ Jogador não encontrado para READY")
                    }

                    updateAllPlayersReady()
                }
            default:
                print("Comando desconhecido:", message)
            }
        }
    
    
    private func removePlayer(_ player: PlayerModel, from side: String) {
            if side == "left" {
                game.sideL.removeAll { $0.name == player.name }
            } else if side == "right" {
                game.sideR.removeAll { $0.name == player.name }
            }
        }

        private func removePlayerByName(_ name: String) {
            game.sideL.removeAll { $0.name == name }
            game.sideR.removeAll { $0.name == name }
        }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    // --- Lógica de Input ---
    
    private func handlePlayerInput(command: String, from connection: NWConnection) {
        guard let playerIndex = players.first(where: { $0.value === connection })?.key else { return }
        
        let moveAmount: CGFloat = 25.0
        let halfPaddle = paddleHeight / 2
        
        let topBound = -(sceneSize.height / 2) + halfPaddle
        let bottomBound = (sceneSize.height / 2) - halfPaddle

        let id = ObjectIdentifier(connection)
        
        // Descobre o lado desse connection com base no JOIN
        guard let info = connectionToPlayer[id] else {
            print("⚠️ handlePlayerInput: conexão sem side associado (JOIN não recebido?)")
            return
        }
        
        let side = info.side
        
        DispatchQueue.main.async {
            if side == "left" {
            if playerIndex == 0 {
                var newY = self.paddleLeftY
                if command == "up" {
                    newY -= moveAmount
                } else if command == "down" {
                    newY += moveAmount
                }
                self.paddleLeftY = min(max(newY, topBound), bottomBound)
                
            } else if side == "right" {
                var newY = self.paddleRightY
                if command == "up" {
                    newY -= moveAmount
                } else if command == "down" {
                    newY += moveAmount
                }
                self.paddleRightY = min(max(newY, topBound), bottomBound)
            } else {
                print("⚠️ Lado desconhecido: \(side)")
            }
        }
    }


    
    
    
    
    
    private func updateAllPlayersReady() {
        let players = connectionToPlayer.values.map { $0.player }

        // Se ninguém está conectado -> não está pronto
        guard !players.isEmpty else {
            allPlayersReady = false
            print("🔄 allPlayersReady → false (nenhum jogador conectado)")
            return
        }

        let everyoneReady = players.allSatisfy { $0.isReady }

        if allPlayersReady != everyoneReady {
            allPlayersReady = everyoneReady
            print("🔄 allPlayersReady → \(everyoneReady)")
            
            if everyoneReady {
                print("🚀 Todos prontos! Enviando START para os iPhones...")
                broadcast(message: "START")
            } else {
                broadcast(message: "STOP")
            }
        }
    }
    private func resetAllPlayersReady() {
        // Zera o isReady de todos os jogadores
        for (key, info) in connectionToPlayer {
            info.player.isReady = false
            connectionToPlayer[key] = info
        }

        // Recalcula o allPlayersReady (vai virar false e mandar STOP)
        updateAllPlayersReady()
    }



    // --- Lógica do "Game Loop" (sem alterações) ---
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
        
        // 1. Atualiza posição
        ballPosition.x += ballVelocity.dx
        ballPosition.y += ballVelocity.dy

        let ballRadius = ballSize / 2
        
        // 2. Bate no teto/chão
        if ballPosition.y <= ballRadius || ballPosition.y >= (sceneSize.height - ballRadius) {
            ballVelocity.dy *= -1
        }
        
        // 3. Retângulo da bola
        let ballRect = CGRect(
            x: ballPosition.x - ballRadius,
            y: ballPosition.y - ballRadius,
            width: ballSize,
            height: ballSize
        )
        
        // 4. Raquetes
        let leftPaddleCenterY = paddleLeftY + (sceneSize.height / 2)
        let rightPaddleCenterY = paddleRightY + (sceneSize.height / 2)

        let paddleLeftRect = CGRect(
            x: 50,
            y: leftPaddleCenterY - (paddleHeight/2),
            width: paddleWidth,
            height: paddleHeight
        )

        let paddleRightRect = CGRect(
            x: sceneSize.width - 50 - paddleWidth,
            y: rightPaddleCenterY - (paddleHeight/2),
            width: paddleWidth,
            height: paddleHeight
        )
        
        // 5. Colisão com raquete esquerda (bola vindo da direita → esquerda)
        if ballRect.intersects(paddleLeftRect) && ballVelocity.dx < 0 {
            // empurra a bola pra fora da raquete pra evitar "grudar"
            ballPosition.x = paddleLeftRect.maxX + ballRadius
            ballVelocity.dx *= -1
        }
        
        // 6. Colisão com raquete direita (bola vindo da esquerda → direita)
        if ballRect.intersects(paddleRightRect) && ballVelocity.dx > 0 {
            ballPosition.x = paddleRightRect.minX - ballRadius
            ballVelocity.dx *= -1
        }
        
        // 7. Pontuação (usa retângulo da bola também se quiser)
        if ballRect.maxX < 0 {
            scoreRight += 1
            resetBall(direction: 1)
        }
        
        if ballRect.minX > sceneSize.width {
            scoreLeft += 1
            resetBall(direction: -1)
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
