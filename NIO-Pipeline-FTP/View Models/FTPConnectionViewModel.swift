//
//  FTPConnectionViewModel.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 11/3/24.
//
import NIO
import Foundation


// NetworkModelDelegate

protocol NetworkModelDelegate: AnyObject {
    func networkDidConnect()
    func networkDidDisconnect()
    func networkDidLogin()
    func networkDidReceiveError(_ error: String)
    func networkDidReceiveDirectoryListing(_ items: [String])
    func networkDidReceiveData(_ data: String)
    func networkDidConnectDataChannel()
    func networkDidDisconnectDataChannel()
    func getResponseCode(_ response: String) -> Int?
    func getResponseMessage(_ response: String) -> String?
    func setCurrentResponse(code: Int, message: String)

}

@Observable
class FTPConnectionViewModel: NetworkModelDelegate {
    
    // Types, variables, etc.
    
    enum CurrentState {
        case connected(FTPState)
        case disconnected
        
        enum FTPState {
            case idle
            case welcome
            case passiveMode
            case dataTransferReady
            case dataTransferInProgress
            case dataTransferComplete
            case waitingForPassword
            case loggedIn
        }
    }
    
    struct ConnectionState {
        var currentState: CurrentState = .disconnected
        var responseCode: Int?
        var responseMessage: String?
        var lastError: String?
    }
    
    struct FileSystemState {
        var currentDirectory: [String] = []
        var currentItems: [FTPListItem] = []
        var currentDirectoryData: String = ""
    }
    
    struct TransferState {
        var isDataChannelConnected = false
    }
    
    struct Credentials {
        var username: String = ""
        var password: String = ""
    }
        
    private let network: NetworkModel
    private var connectionState: ConnectionState = ConnectionState()
    private var fileSystemState: FileSystemState = FileSystemState()
    private var transferState: TransferState = TransferState()
    private var credentials: Credentials = Credentials()
        
    var currentResponseMessage: String? {
        get { connectionState.responseMessage }
        set {
            connectionState.responseMessage = newValue
            if let message = newValue {
                print("New response: \(message)")
            }
        }
    }
    
    var currentResponseCode: Int? {
        get { connectionState.responseCode }
        set {
            connectionState.responseCode = newValue
            if let code = newValue {
                print("New Code: \(code)")
                updateStateFromResponse(code)
                stateManager()
            }
        }
    }
    
    var isConnected: Bool {
        if case .connected = connectionState.currentState {
            return true
        }
        return false
    }
    
    var isLoggedIn: Bool {
        if case .connected(let ftpState) = connectionState.currentState {
            return ftpState == .loggedIn
        }
        return false
    }
    
    var currentItems: [FTPListItem] {
        get { fileSystemState.currentItems }
        set { fileSystemState.currentItems = newValue }
    }
    
    // State manager
    
    private func updateStateFromResponse(_ code: Int) {
        let newState: CurrentState = switch code {
        case 220: .connected(.welcome)
        case 331: .connected(.waitingForPassword)
        case 230: .connected(.loggedIn)
        case 227: .connected(.passiveMode)
        case 150: .connected(.dataTransferReady)
        case 226: .connected(.dataTransferComplete)
        default: connectionState.currentState
        }
        connectionState.currentState = newState
    }
    
    private func stateManager() {
        switch connectionState.currentState {
        case .disconnected:
            print("Disconnected")
            
        case .connected(let ftpState):
            switch ftpState {
            case .idle: break
            case .welcome:
                sendFTPCommand("USER \(credentials.username)\r\n")
                networkDidConnect()
            case .waitingForPassword:
                sendFTPCommand("PASS \(credentials.password)\r\n")
            case .loggedIn:
                sendFTPCommand("PASV\r\n")
                networkDidLogin()
                
            case .passiveMode, .dataTransferReady, .dataTransferInProgress, .dataTransferComplete:
                break
            }
        }
    }
    
    // Helper functions for UI
    
    func login(username: String, password: String) {
        credentials.username = username
        credentials.password = password
        connectionState.currentState = .connected(.idle)
    }
    
    func connect(host: String, port: Int) {
        network.createControlChannel(connectionInfo: ConnectionInformation(
            isConnected: nil,
            ipAddress: host,
            port: port
        ))
    }
    
    func ftpsConnect(host: String, port: Int) {
        network.ftpsCreateControlChannel(connectionInfo: ConnectionInformation(
            isConnected: nil,
            ipAddress: host,
            port: 990
        ))
        
    }
    
    func disconnect() {
        network.disconnect()
        connectionState.currentState = .disconnected
    }
    
    func sendFTPCommand(_ command: String) {
        network.sendCommand(command)
    }
    
    func changeDirectory(_ path: String) {
        network.sendCommand("CWD \(path)\r\n")
    }
    
    func requestDirectoryListing() {
        network.sendCommand("PASV\r\n")
        network.sendCommand("LIST\r\n")
    }
    
    // Parsers
    
    private func parseListResponse(_ data: String) -> [FTPListItem] {
        data.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line -> FTPListItem? in
                let isDirectory = line.hasPrefix("d")
                let components = line.split(separator: " ")
                guard let name = components.last else { return nil }
                
                return FTPListItem(
                    name: String(name),
                    type: isDirectory ? .directory : .file,
                    size: nil,
                    modificationDate: nil
                )
            }
    }
    
    private func parseResponse(_ response: String) -> (code: Int, message: String)? {
        guard response.count >= 3,
              let code = Int(response.prefix(3)) else {
            return nil
        }
        let message = String(response.dropFirst(4))
        return (code, message)
    }
    

    
    
    func networkDidConnect() {
        connectionState.currentState = .connected(.idle)
    }
    
    func networkDidDisconnect() {
        connectionState.currentState = .disconnected
    }
    
    func networkDidLogin() {
        connectionState.currentState = .connected(.loggedIn)
    }
    
    func networkDidReceiveError(_ error: String) {
        connectionState.lastError = error
    }
    
    func networkDidReceiveDirectoryListing(_ items: [String]) {
        fileSystemState.currentDirectory = items
    }
    
    func networkDidConnectDataChannel() {
        transferState.isDataChannelConnected = true
    }
    
    func networkDidDisconnectDataChannel() {
        transferState.isDataChannelConnected = false
    }
    
    func networkDidReceiveData(_ data: String) {
        fileSystemState.currentItems = parseListResponse(data)
    }
    
    func getResponseCode(_ response: String) -> Int? {
        parseResponse(response)?.code
    }
    
    func getResponseMessage(_ response: String) -> String? {
        parseResponse(response)?.message
    }
    
    func setCurrentResponse(code: Int, message: String) {
        currentResponseCode = code
        currentResponseMessage = message
    }
    
    // Init delegate here
    
    init() {
        self.network = NetworkModel()
        self.network.delegate = self
    }
}

