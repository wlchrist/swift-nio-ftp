//
//  ContentView.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 10/25/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(NetworkModel.self) private var network
    let sendHandler = ChannelSendHandler()
    
    var body: some View {
        VStack {
            Image(systemName: "network")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Divider()
            
            Button("Connect") {
                network.channelCreate(connectionInfo: ConnectionInformation.init(isConnected: nil, ipAddress: "127.0.0.1", port: 21))
            }
            Divider()
            Button("Login") {
                network.sendCommand("USER test\r\n")
                network.sendCommand("PASS test\r\n")
            }
            
            Divider()
            
            Button("List") {
                network.sendCommand("LIST \r\n")
            }
        }
        .padding()
    }
}

/*
 #Preview {
 ContentView()
 }
 */

