//
//  NIO_Pipeline_FTPApp.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 10/25/24.
//

import SwiftUI
import Foundation

@main
struct NIO_Pipeline_FTPApp: App {
    @State private var network = NetworkModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(network)
        }
    }
}
