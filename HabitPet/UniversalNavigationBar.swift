//
//  UniversalNavigationBar.swift
//  HabitPet
//
//  Created by Janice C on 9/23/25.
//

import SwiftUI

// MARK: - Universal Navigation Bar
struct UniversalNavigationBar: View {
    let onHome: () -> Void
    let onRecipes: () -> Void
    let onCamera: () -> Void
    let onStats: () -> Void
    let onProfile: () -> Void
    let currentScreen: NavigationScreen
    
    var body: some View {
        HStack(spacing: 0) {
            navItem(icon: "house.fill", title: "Home", action: onHome, isSelected: currentScreen == .home)
            navItem(icon: "book", title: "Recipes", action: onRecipes, isSelected: currentScreen == .recipes)

            Button(action: onCamera) { // center +
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#06b6d4"), Color(hex: "#3b82f6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    Image(systemName: "plus")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .offset(y: -10)
                .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Food Camera")

            navItem(icon: "chart.bar.fill", title: "Stats", action: onStats, isSelected: currentScreen == .stats)
            navItem(icon: "person.circle", title: "Profile", action: onProfile, isSelected: currentScreen == .profile)
        }
        .background(Color.white)
        .overlay(Rectangle().frame(height: 0.5).foregroundColor(Color.gray.opacity(0.3)), alignment: .top)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
    }

    private func navItem(icon: String, title: String, action: @escaping () -> Void, isSelected: Bool) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? Color(hex: "#06b6d4") : .gray)
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? Color(hex: "#06b6d4") : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Navigation Screen Enum
enum NavigationScreen {
    case home, recipes, camera, stats, profile
    
    static var allCases: [NavigationScreen] {
        return [.home, .recipes, .camera, .stats, .profile]
    }
}

// MARK: - Preview
struct UniversalNavigationBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            UniversalNavigationBar(
                onHome: {},
                onRecipes: {},
                onCamera: {},
                onStats: {},
                onProfile: {},
                currentScreen: .home
            )
        }
        .background(Color.gray.opacity(0.1))
    }
}
