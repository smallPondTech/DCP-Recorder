//
//  DCP_RecorderApp.swift
//  DCP Recorder
//
//  Created by Brian Haeffner on 8/1/26.
//

import SwiftUI
import SwiftData

@main
struct DCP_RecorderApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DCPProject.self,
            DCPProjectBlow.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isRunningForPreviews,
            cloudKitDatabase: shouldUseCloudKit ? .private("iCloud.com.smallpondtech.DCP-Recorder") : .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    private static var shouldUseCloudKit: Bool {
#if targetEnvironment(simulator)
        false
#else
        !isRunningForPreviews
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
