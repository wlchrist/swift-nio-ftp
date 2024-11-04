//
//  FTPConnectionViewModel.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 11/3/24.
//
import NIO
import Foundation

@Observable
class FTPConnectionViewModel: NetworkModelDelegate {

    
    
    var pendingUsername: String = ""
    var pendingPassword: String = ""
    var isConnected = false
    var isLoggedIn = false
    var currentDirectory: [String] = []
    var isDataChannelConnected = false
    var currentDirectoryData: String = ""
    var lastError: String?
    var currentItems: [FTPListItem] = []
    var currentConnectionState: CurrentState = .disconnected
    var currentFTPState: CurrentState.FTPState = .idle
    var isDownloadComplete: Bool = false
    
    private let network: NetworkModel

    var currentResponseMessage: String? {
            didSet {
                if let message = currentResponseMessage {
                    print("New response: \(message)")
                }
            }
        }
    
    var currentResponseCode: Int? {
       didSet {
           if let code = currentResponseCode {
               print("New Code: \(code)")
               updateStateFromResponse(code)
               stateManager()
           }
       }
    }
    
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
    
    private func updateStateFromResponse(_ code: Int) {
       switch code {
       case FTPResponseCode.welcome.rawValue:  // 220
           currentConnectionState = .connected(.welcome)
       case FTPResponseCode.passwordRequired.rawValue:  // 331
           currentConnectionState = .connected(.waitingForPassword)
       case FTPResponseCode.loggedIn.rawValue:  // 230
           currentConnectionState = .connected(.loggedIn)
       case FTPResponseCode.enteringPassiveMode.rawValue: // 227
           currentConnectionState = .connected(.passiveMode)
       case FTPResponseCode.fileStatusOK.rawValue: // 150
           currentConnectionState = .connected(.dataTransferReady)
       case FTPResponseCode.closingDataConnection.rawValue: // 226
           currentConnectionState = .connected(.dataTransferComplete)
       default:
           break
       }
    }

    private func stateManager() {
       switch currentConnectionState {
       case .disconnected:
           print("Disconnected")
           
       case .connected(let ftpState):
           switch ftpState {
           case .idle:
               break
           case .welcome:
               sendFTPCommand("USER \(pendingUsername)\r\n")
               networkDidConnect()
           case .waitingForPassword:
            sendFTPCommand("PASS \(pendingPassword)\r\n")
           case .loggedIn:
               sendFTPCommand("PASV\r\n")
               networkDidLogin()
           case .passiveMode:
               break
           case .dataTransferReady:
               break
           case .dataTransferInProgress:
               break
           case .dataTransferComplete:
               isDownloadComplete = true
               break
           
           }
       }
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
    
    func login(username: String, password: String) {
        
        self.pendingUsername = username
        self.pendingPassword = password
        currentConnectionState = .connected(.idle)
    }
    
    
    func disconnect() {
        network.disconnect()
        isLoggedIn = false
        isConnected = false
    }
    
    private func parseListResponse(_ data: String) -> [FTPListItem] {
        return data.components(separatedBy: "\n")
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
    
    
    
    
    
    // delegate methods
    func networkDidConnect() {
        isConnected = true
    }
    
    func networkDidDisconnect() {
        isConnected = false
        isLoggedIn = false
    }
    
    func networkDidLogin() {
        isLoggedIn = true
    }
    
    func networkDidReceiveError(_ error: String) {
        lastError = error
    }
    
    func networkDidReceiveDirectoryListing(_ items: [String]) {
        currentDirectory = items
    }
    
    func networkDidConnectDataChannel() {
            isDataChannelConnected = true
        }
    
    func networkDidDisconnectDataChannel() {
        isDataChannelConnected = false
    }
    
    
    func networkDidReceiveData(_ data: String) {
        currentItems = parseListResponse(data)
        }
    
    func getResponseCode(_ response: String) -> Int? {
        return parseResponse(response)?.code
    }

    func getResponseMessage(_ response: String) -> String? {
        return parseResponse(response)?.message
    }

    func setCurrentResponse(code: Int, message: String) {
           currentResponseCode = code
           currentResponseMessage = message
       }
    
    init() {
            self.network = NetworkModel()
            self.network.delegate = self
        }
    
    func connect(host: String, port: Int) {
        network.controlChannelCreate(connectionInfo: ConnectionInformation(
            isConnected: nil,
            ipAddress: host,
            port: port
        ))
    }

}
