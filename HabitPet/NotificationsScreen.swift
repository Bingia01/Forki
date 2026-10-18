//
//  NotificationsScreen.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI

struct NotificationsScreen: View {
    @Binding var currentScreen: Int
    @Binding var userData: UserData
    
    @State private var notificationError: String?
    @State private var requesting = false
    var body: some View {
        ZStack {
            background
            content
        }
        .disabled(requesting)
        .alert("Meal Reminders", isPresented: Binding(get: { notificationError != nil }, set: { if !$0 { notificationError = nil } })) {
            Button("OK") { notificationError = nil }
        } message: { Text(notificationError ?? "") }
    }
    
    // MARK: Background
    private var background: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#8b5cf6"), // violet-500
                Color(hex: "#a855f7"), // purple-500
                Color(hex: "#d946ef")  // fuchsia-500
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: Content
    private var content: some View {
        VStack(spacing: 24) {
            // Icon
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 96, height: 96)
                    Image(systemName: "bell.badge")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                }
                .padding(.bottom, 16)
            }
            
            // Header
            VStack(spacing: 8) {
                Text("Stay on track with reminders")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Get a gentle reminder to log breakfast, lunch, and dinner.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(text: "Daily meal logging reminders")
                BenefitRow(text: "Breakfast, lunch, and dinner reminders")
                BenefitRow(text: "Manage reminders in your profile")
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            
            // Buttons
            VStack(spacing: 16) {
                Button {
                    requesting = true
                    Task { @MainActor in
                        defer { requesting = false }
                        do {
                            userData.notifications = try await MealReminders.configure(enabled: true)
                            if !userData.notifications {
                                notificationError = "Notifications are disabled. You can enable them in Settings, or choose Maybe Later."
                            } else { currentScreen = 6 }
                        } catch { notificationError = "Reminders could not be scheduled. Please try again." }
                    }
                } label: {
                    Text("Enable Notifications")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(Color.purple)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                }
                
                Button {
                    userData.notifications = false
                    UserDefaults.standard.set(true, forKey: "hp_isSignedIn")
                    UserDefaults.standard.set(true, forKey: "hp_hasOnboarded")
                    withAnimation { currentScreen = 6 }
                } label: {
                    Text("Maybe Later")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundColor(.white)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            

        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Preview
#Preview {
    NotificationsScreen(
        currentScreen: .constant(5),
        userData: .constant(UserData())
    )
}
