import Foundation
import SwiftUI
import NIO


// Using Queue-based approach for sending commands up the channel pipeline to our endpoint & receiving responses downstream.

// FTP Response codes
enum FTPResponseCode: Int {
    case ready = 220
    case loggedIn = 230
    case passwordRequired = 331
    case enteringPassiveMode = 227
    case fileStatusOK = 150
    case closingDataConnection = 226
    case commandOK = 200
    
    var isPositive: Bool {
        return (200...399).contains(rawValue)
    }
}

enum FTPEvent {
    case ready
    case passwordRequired
    case loggedIn
    case passiveMode
}

struct FTPResponse {
    let code: Int
    let message: String
    
    var isPositive: Bool {
        return (200...399).contains(code)
    }
}

struct ConnectionInformation {
    var isConnected: Bool?
    var ipAddress: String?
    var port: Int?
    var passivePort: Int?
}



@Observable class NetworkModel {
    private var controlChannel: Channel?
    private var dataChannel: Channel?
    private var eventLoopGroup: MultiThreadedEventLoopGroup?
    private var commandQueue: [String] = []
    private var isProcessingCommand = false
    
    
    
    func controlChannelCreate(connectionInfo: ConnectionInformation) {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        guard let eventLoopGroup = eventLoopGroup else { return }
        
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    ChannelReadHandler(),
                    LineBufferHandler(),
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
    
    func dataChannelCreate(connectionInfo: ConnectionInformation) {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        guard let eventLoopGroup = eventLoopGroup else { return }
        
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    ChannelReadHandler()
                ])
            }
        
        guard let host = connectionInfo.ipAddress else {
            return
        }
        
        guard let port = connectionInfo.port else {
            return
        }
        
        
        Task {
            do {
                self.dataChannel = try await bootstrap.connect(host: host, port: port).get()
                print("Connected to \(host) on port \(port)")
            } catch {
                print("Failed to connect: \(error)")
            }
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
        sendCommand("QUIT\r\n")
        controlChannel?.close(promise: nil)
        dataChannel?.close(promise: nil)
        try? eventLoopGroup?.syncShutdownGracefully()
        controlChannel = nil
        dataChannel = nil
        eventLoopGroup = nil
    }
}

class ChannelReadHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        guard let response = buffer.readString(length: buffer.readableBytes) else {
            print("Error reading from buffer")
            return
        }
        print(response)
        context.fireChannelRead(data)
    }
}


class ChannelSendHandler: ChannelOutboundHandler {
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        context.write(wrapOutboundOut(buffer), promise: promise)
    }
}


class LineBufferHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    
    private var buffer: String = ""
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buff = unwrapInboundIn(data)
        guard let received = buff.readString(length: buff.readableBytes) else {
            return
        }
        
        buffer += received
        
        while let newlineIndex = buffer.firstIndex(of: "\r\n") {
            let line = String(buffer[..<newlineIndex])
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleanLine.isEmpty {
                serverResponseDispatcher(response: cleanLine)
                var outBuff = context.channel.allocator.buffer(capacity: cleanLine.utf8.count)
                outBuff.writeString(cleanLine)
                context.fireChannelRead(self.wrapInboundOut(outBuff))
                
            }
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
        }
    }
    
    // precondition: response code is already valid
    private func serverResponseDispatcher(response: String){
        
        let code = responsePrefix(buffer: response)
        switch FTPResponseCode(rawValue: code) {
        case .enteringPassiveMode, .fileStatusOK:
            
            NetworkModel().dataChannelCreate(connectionInfo: ConnectionInformation(
                isConnected: nil,
                ipAddress: "127.0.0.1",
                port: passiveModePort(buffer)
            ))
            
        default:
            break
        }
    }
    
    // Example response: "227 Entering Passive Mode (192,168,1,100,234,21)"
    private func passiveModePort(_ response: String?) -> Int? {
        
        guard let response = response else {return nil}
        guard let numbersString = response.split(separator: "(").last?.split(separator: ")").first else {return nil}
        
        let numbers = numbersString.split(separator: ",").compactMap {Int($0)}
        
        guard numbers.count == 6 else {return nil}
        
        let port = (numbers[4] * 256) + numbers[5]
        
        return port
    }
    
    private func responsePrefix(buffer: String?) -> Int {
        guard let prefix = buffer?.prefix(3) else { return 0 }
        return Int(prefix) ?? 0
    }
}
