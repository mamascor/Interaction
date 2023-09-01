//
//  InteractionApp.swift
//  Interaction
//
//  Created by Marco Mascorro on 9/1/23.
//

import SwiftUI

@main
struct InteractionApp: App {
    var body: some Scene {
        WindowGroup {
            if InteractionViewModel.nearbySessionAvailable {
                ContentView()
            } else {
                ErrorView()
            }
           
        }
    }
}
