//
//  ContentView.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 10/25/24.
//

import SwiftUI



struct ContentView: View {
    @Environment(FTPConnectionViewModel.self) private var ftpConnectionViewModel
    
    var body: some View {
        NavigationStack {
            if (ftpConnectionViewModel.isConnected == true) {
                FileListView()
            } else {
                LoginView()
            }
        }
    }
}
