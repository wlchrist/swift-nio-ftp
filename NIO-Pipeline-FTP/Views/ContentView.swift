//
//  ContentView.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 10/25/24.
//

import SwiftUI

    struct ContentView: View {
    @Environment(NetworkModel.self) private var network
    @State private var isConnected = false
    @State private var isLoggedIn = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isConnected ? "network" : "network.slash")
                .imageScale(.large)
                .foregroundStyle(isConnected ? .green : .red)
            
            Button(isConnected ? "Disconnect" : "Connect") {
                if isConnected {
                    network.disconnect()
                    isConnected = false
                    isLoggedIn = false
                } else {
                    network.controlChannelCreate(connectionInfo: ConnectionInformation(
                        isConnected: nil,
                        ipAddress: "127.0.0.1",
                        port: 21
                    ))
                    isConnected = true
                }
            }
            
            Button("Login") {
                network.sendCommand("USER test\r\n")
                network.sendCommand("PASS test\r\n")
                isLoggedIn = true
            }
            .disabled(!isConnected || isLoggedIn)
        }
        .padding()
    }
}
