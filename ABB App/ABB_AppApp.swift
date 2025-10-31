//
//  ABB_AppApp.swift
//  ABB App
//
//  Created by Artem on 28.07.2025.
//

import SwiftUI
import IndustrialKit

@main
struct ABB_AppApp: App
{
    @StateObject var connector = ABBConnector()
    @StateObject var tool_connector = GripperConnector()
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .environmentObject(connector)
                .environmentObject(tool_connector)
        }
        .windowResizability(.contentSize)
    }
}
