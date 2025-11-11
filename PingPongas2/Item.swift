//
//  Item.swift
//  PingPongas2
//
//  Created by Gustavo Souza Santana on 11/11/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
