//
//  GameModel.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana.
//  Created by Ruan Lopes Viana.

import Foundation
import SwiftData

@Model
final class GameModel {
    var sideL: [PlayerModel] = []
    var scoreL: Int = 0
    
    var sideR: [PlayerModel] = []
    var scoreR: Int = 0
    
    init(sideL: [PlayerModel], scoreL: Int, sideR: [PlayerModel], scoreR: Int) {
        self.sideL = sideL
        self.scoreL = scoreL
        self.sideR = sideR
        self.scoreR = scoreR
    }
}

