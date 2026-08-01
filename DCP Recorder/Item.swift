//
//  Item.swift
//  DCP Recorder
//
//  Created by Brian Haeffner on 8/1/26.
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
