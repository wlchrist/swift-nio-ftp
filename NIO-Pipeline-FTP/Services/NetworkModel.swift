//
//  NetworkModel.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 11/3/24.
//
import Foundation
import NIO
import NIOSSL

struct ConnectionInformation {
    var isConnected: Bool?
    var ipAddress: String?
    var port: Int?
    
    
    static let defaultInfo = ConnectionInformation(
        isConnected: nil,
        ipAddress: nil,
        port: 21
    )
}


struct FTPListItem: Identifiable {
    let id = UUID()
    let name: String
    let type: ItemType
    let size: Int64?
    let modificationDate: Date?
    
    enum ItemType {
        case file
        case directory
    }
}


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


@Observable class NetworkModel {
    weak var delegate: NetworkModelDelegate?
    private var controlChannel: Channel?
    private var dataChannel: Channel?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var commandQueue: [String] = []
    private var isProcessingCommand = false
    
    func createControlChannel(connectionInfo: ConnectionInformation) {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        guard let eventLoopGroup = eventLoopGroup else { return }
        
        // response handler initialization
        let responseHandler = LineBufferHandler()
        responseHandler.networkModel = self
        
        // FTP bootstrap
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    ChannelReadHandler(),
                    responseHandler,
                    ChannelSendHandler()
                ])
            }
        
        
        guard let host = connectionInfo.ipAddress else {
            print("Invalid IP address")
            return
        }
        
        guard let port = connectionInfo.port else {
            print("Invalid port number")
            return
        }
        
        
        Task {
            do {
                self.controlChannel = try await bootstrap.connect(host: host, port: port).get()
                print("Connected to \(host) on port \(port)")
            } catch {
                print("Failed to connect: \(error)")
            }
        }
    }
    
    func createDataChannel(port: Int) {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        guard let eventLoopGroup = eventLoopGroup else {
            delegate?.networkDidReceiveError("Failed to create event loop group")
            return
        }
        
        let dataHandler = DataChannelHandler()
        dataHandler.networkModel = self
        
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    dataHandler
                ])
            }
        
        
        guard let host = controlChannel?.remoteAddress?.ipAddress else {
            print("Could not determine remote address for data channel")
            return
        }
        
        Task {
            do {
                self.dataChannel = try await bootstrap.connect(host: host, port: port).get()
                print("Connected to \(host) on port \(port)")
                delegate?.networkDidConnectDataChannel()
            } catch {
                print("Failed to connect: \(error)")
                delegate?.networkDidReceiveError("Data channel connection failed: \(error.localizedDescription)")
            }
        }
    }
    
    
    // FTPS bootstrap
    func ftpsCreateControlChannel(connectionInfo: ConnectionInformation) {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        guard let eventLoopGroup = eventLoopGroup else { return }
        
        let responseHandler = LineBufferHandler()
        responseHandler.networkModel = self
        
        do {
            let configuration = TLSConfiguration.makeClientConfiguration()
            let sslContext = try NIOSSLContext(configuration: configuration)
            let handler = try NIOSSLClientHandler(context: sslContext, serverHostname: connectionInfo.ipAddress)
            
            let ftpsBootstrap = ClientBootstrap(group: eventLoopGroup)
                .channelInitializer { channel in
                    channel.pipeline.addHandlers([
                        handler
                    ])
                }
            
            guard let host = connectionInfo.ipAddress else {
                print("Invalid IP address")
                return
            }
            
            guard let port = connectionInfo.port else {
                print("Invalid port number")
                return
            }
            
            Task {
                self.controlChannel = try await ftpsBootstrap.connect(host: host, port: port).get()
            }
            
        } catch {
            print("Error during FTPS configuration: \(error)")
        }
        
    }
    
    
    func sendCommand(_ command: String) {
        commandQueue.append(command)
        processNextCommand()
    }
    
    private func processNextCommand() {
        guard !isProcessingCommand,
              let command = commandQueue.first,
              let channel = controlChannel else {
            return
        }
        
        isProcessingCommand = true
        
        var buffer = channel.allocator.buffer(capacity: command.utf8.count)
        buffer.writeString(command)
        
        let promise = channel.eventLoop.makePromise(of: Void.self)
        
        promise.futureResult.whenComplete { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                print("Sent command: \(command.trimmingCharacters(in: .newlines))")
                self.commandQueue.removeFirst()
                self.isProcessingCommand = false
                self.processNextCommand()
                
            case .failure(let error):
                print("Failed to send command: \(error)")
                self.commandQueue.removeFirst()
                self.isProcessingCommand = false
                self.processNextCommand()
            }
        }
        
        channel.writeAndFlush(buffer, promise: promise)
    }
    
    
    
    func disconnect() {
        controlChannel?.close(promise: nil)
        dataChannel?.close(promise: nil)
        try? eventLoopGroup?.syncShutdownGracefully()
        controlChannel = nil
        dataChannel = nil
        eventLoopGroup = nil
    }
}




