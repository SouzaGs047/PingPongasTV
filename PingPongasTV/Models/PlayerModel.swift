//
//  PlayerModel.swift
//  PingPongasTV
//
//  Created by Gustavo Souza Santana on 11/11/25.
//

import Foundation
import SwiftData

@Model
final class PlayerModel {
    var name: String

    init(name: String) {
        self.name = name
    }
}
