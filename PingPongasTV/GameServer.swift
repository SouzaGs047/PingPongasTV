//
//  GameServer.swift
//  PingPongas2
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
            print("Cliente mudou:", state)

            switch state {
            case .failed(_), .cancelled:
                self?.handleClientDisconnect(connection)

            default:
                break
            }
        }

        connection.start(queue: .main)
        receive(connection)

        if clients.count == 1 {
            print("1 cliente conectado → parando listener")
            listener?.cancel()
            listener = nil
            isListening = false
        }
    }

    private func handleClientDisconnect(_ connection: NWConnection) {
        print("Cliente desconectou:", connection)
        clients.removeAll { $0 === connection }

        if clients.isEmpty {
            print("Nenhum cliente → reiniciando listener...")
            start()
        }
    }

    private func receive(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, _, error in
            
            if let data = data, let str = String(data: data, encoding: .utf8) {
                print("Recebido do iPhone:", str)
            }

            if error == nil {
                self?.receive(connection)
            } else {
                // Se der erro, tratar desconexão corretamente
                self?.handleClientDisconnect(connection)
            }
        }
    }

    func broadcast(message: String) {
        let data = message.data(using: .utf8)!
        for client in clients {
            client.send(content: data, completion: .contentProcessed { _ in })
        }
    }
}
