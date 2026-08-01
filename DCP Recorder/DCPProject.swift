//
//  DCPProject.swift
//  DCP Recorder
//
//  Created by Brian Haeffner on 8/1/26.
//

import Foundation
import SwiftData

@Model
final class DCPProject {
    var title: String = "Untitled Project"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var unitSystemRawValue: String = "english"

    @Relationship(deleteRule: .cascade, inverse: \DCPProjectBlow.project)
    var blows: [DCPProjectBlow]? = []

    init(
        title: String = "Untitled Project",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        unitSystemRawValue: String = "english",
        blows: [DCPProjectBlow] = []
    ) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.unitSystemRawValue = unitSystemRawValue
        self.blows = blows
    }
}

@Model
final class DCPProjectBlow {
    var position: Int = 0
    var incrementalPenetration: Double = 0
    var project: DCPProject?

    init(position: Int = 0, incrementalPenetration: Double = 0, project: DCPProject? = nil) {
        self.position = position
        self.incrementalPenetration = incrementalPenetration
        self.project = project
    }
}
