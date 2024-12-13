//
//  LoginView.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 11/2/24.
//

import SwiftUI

struct LoginView: View {
    @Environment(FTPConnectionViewModel.self) private var ftpConnectionViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "network")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Button("Connect") {
                //ftpConnectionViewModel.connect(host: "127.0.0.1", port: 21)
                //ftpConnectionViewModel.login(username: "demo", password: "password")
                //ftpConnectionViewModel.ftpsConnect(host: "test.rebex.net", port: 21)
                ftpConnectionViewModel.ftpsConnect(host: "ftp.dlptest.com", port: 21)
                ftpConnectionViewModel.login(username: "dlpuser", password: "rNrKYTX9g7z3RgJRmxWuGHbeu")
            }
        }
        .padding()
    }
}

#Preview {

}


#Preview
{
    LoginView()
}
