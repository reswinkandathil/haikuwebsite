//
//  clockApp.swift
//  clock
//
//  Created by Reswin Kandathil on 3/7/26.
//

import SwiftUI

@main
struct clockApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("isPro") private var isPro = false
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
    }
}
