//
//  ContentView.swift
//  LMS Staff
//
//  Main application router and global interaction detection.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            switch authViewModel.authState {
            case .splash:
                SplashView()
            case .unauthenticated:
                StaffLoginView()
            case .authenticated(let role):
                StaffTabRouter(role: role)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { _ in
                    NotificationCenter.default.post(name: NSNotification.Name("UserDidInteract"), object: nil)
                }
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthViewModel())
    }
}
