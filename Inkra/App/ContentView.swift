//
//  ContentView.swift
//  Inkra
//
//  Created by Magnus Fremont on 7/14/25.
//
import SwiftUI

@available(iOS 15.0, macOS 11.0, *)
struct ContentView: View {
    @State private var showPermissionsCheck = true
    @State private var hasCheckedPermissions = false

    var body: some View {
        Group {
            if showPermissionsCheck && !hasCheckedPermissions {
                PermissionsCheckView {
                    showPermissionsCheck = false
                    hasCheckedPermissions = true
                }
            } else {
                HomeView()
            }
        }
    }
}

#Preview {
    ContentView()
}
