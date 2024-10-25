//
//  NIO.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 10/25/24.
//

import Foundation
import SwiftUI
import NIO


struct ConnectionInformation {
    var isConnected: Bool?
    var ipAddress: String?
    var port: Int?
    var dataConnection: Bool = false
    
}

@Observable class NetworkModel {
    private var channel: Channel?
    
    func channelCreate(connectionInfo: ConnectionInformation) {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let bootstrap = ClientBootstrap(group: eventLoopGroup)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    ChannelReadHandler(),
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
        
        bootstrap.connect(host: host, port: port).whenComplete { [weak self] result in
            switch result {
            case .success(let channel):
                print("Connected to \(host) on port \(String(describing: connectionInfo.port))")
                self?.channel = channel // saves a reference to channel in model
                
            case .failure(let error):
                print("Failed to connect: \(error)")
            }
        }
        
        
    }
    
    func sendCommand(_ message: String) {
        
        guard let channel = channel else {
            print("No active connection to send command.")
            return
        }
        
        var buffer = channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        channel.writeAndFlush(buffer, promise: nil)
    }
}
    

    class ChannelReadHandler: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        typealias OutboundOut = ByteBuffer
        
        func channelActive(context: ChannelHandlerContext) {
            print("Channel is active and connected.")
        }
        
        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            
            
            if (ConnectionInformation.dataConnection == false) {
                
                var buff = self.unwrapInboundIn(data)
                let str = buff.readString(length: buff.readableBytes)
                print(str ?? "bad string")
                
                
            }

        }
        
    }
    
    class ChannelSendHandler: ChannelOutboundHandler {
        typealias OutboundIn = ByteBuffer
        typealias OutboundOut = ByteBuffer
        
        func channelSend(_ message: String, context: ChannelHandlerContext){
            var buff = context.channel.allocator.buffer(string: message)
            buff.writeString(message)
            context.writeAndFlush(self.wrapOutboundOut(buff), promise: nil)
        }
    }
