import Foundation
import SwiftUI
import NIO


class ChannelReadHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        
        guard buffer.readString(length: buffer.readableBytes) != nil else {
            print("Error reading from buffer")
            return
        }
        context.fireChannelRead(data)
    }
}

class LineBufferHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    weak var networkModel: NetworkModel?
    private var buffer: String = ""
    private var code: Int?
    private var message: String?
    
    
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buff = unwrapInboundIn(data)
        guard let received = buff.readString(length: buff.readableBytes) else {
            return
        }
        
        buffer += received
        
        while let newlineIndex = buffer.firstIndex(of: "\r\n") {
            let line = String(buffer[..<newlineIndex])
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let code = networkModel?.delegate?.getResponseCode(cleanLine) else {return}
            guard let message = networkModel?.delegate?.getResponseMessage(cleanLine) else {return}
            
            networkModel?.delegate?.setCurrentResponse(code: code, message: message)
            
            // always list
            if(code == 150 || code == 227) {
                if passiveModePort(message) != nil {
                    networkModel?.dataChannelCreate(port: passiveModePort(message) ?? 22)
                    networkModel?.sendCommand("LIST\r\n")
                }
            }
            
            if !cleanLine.isEmpty {
                var outBuff = context.channel.allocator.buffer(capacity: cleanLine.utf8.count)
                outBuff.writeString(cleanLine)
                context.fireChannelRead(self.wrapInboundOut(outBuff))
                
            }
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
        }
    }
    
    
    private func passiveModePort(_ response: String?) -> Int? {
        guard let response = response,
              let startIndex = response.firstIndex(of: "("),
              let endIndex = response.firstIndex(of: ")") else {
            return nil
        }
        
        let addressAndPortString = response[response.index(after: startIndex)..<endIndex]
        
        let components = addressAndPortString.split(separator: ",").compactMap { Int($0) }
        
        guard components.count == 6 else { return nil }
        
        let port = (components[4] * 256) + components[5]
        print(port)
        return port
    }
}



class DataChannelHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer
    typealias InboundOut = ByteBuffer
    
    weak var networkModel: NetworkModel?
    private var buffer = String()
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var byteBuffer = unwrapInboundIn(data)
        if let received = byteBuffer.readString(length: byteBuffer.readableBytes) {
            buffer += received
            networkModel?.delegate?.networkDidReceiveData(received)
            print(received)
        }
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        networkModel?.delegate?.networkDidDisconnectDataChannel()
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
