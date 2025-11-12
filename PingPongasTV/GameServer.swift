//
//  GameServer.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana on 11/11/25.
//


import Foundation
import Network
import Combine

class GameServer: ObservableObject {
    private var listener: NWListener?
    private var isListening = false
    
    @Published var clients: [NWConnection] = []
    @Published var game = GameModel(sideL: [], scoreL: 0, sideR: [], scoreR: 0)
    
    // Mapeia cada conexão a um jogador e lado
    private var connectionToPlayer: [ObjectIdentifier: (player: PlayerModel, side: String)] = [:]
    
    func start() {
        guard !isListening else { return }
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
        clients.append(connection)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(_), .cancelled:
                self?.handleClientDisconnect(connection)
            default:
                break
            }
        }
        
        connection.start(queue: .main)
        receive(connection)
    }
    
    private func handleClientDisconnect(_ connection: NWConnection) {
        print("Cliente desconectou:", connection)
        clients.removeAll { $0 === connection }
        
        let id = ObjectIdentifier(connection)
        if let info = connectionToPlayer[id] {
            removePlayer(info.player, from: info.side)
            connectionToPlayer.removeValue(forKey: id)
            print("Removido \(info.player.name) do lado \(info.side)")
        }
        
        if clients.isEmpty {
            print("Nenhum cliente → reiniciando listener...")
            start()
        }
    }
    
    private func receive(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, _, error in
            if let data = data, let str = String(data: data, encoding: .utf8) {
                self?.handleMessage(str, from: connection)
            }
            if error == nil {
                self?.receive(connection)
            } else {
                self?.handleClientDisconnect(connection)
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
                removePlayerByName(name)
                connectionToPlayer = connectionToPlayer.filter { $0.value.player.name != name }
                print("Jogador \(name) saiu manualmente")
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

    func broadcast(message: String) {
        let data = message.data(using: .utf8)!
        for client in clients {
            client.send(content: data, completion: .contentProcessed { _ in })
        }
    }
}
