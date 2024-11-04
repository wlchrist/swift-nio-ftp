//
//  FileListView.swift
//  NIO-Pipeline-FTP
//
//  Created by Warren Christian on 11/2/24.
//

import SwiftUI

struct FileListView: View {
    @Environment(FTPConnectionViewModel.self) private var viewModel
    @State private var currentPath = "/"
    
    var body: some View {
        List {
            if currentPath != "/" {
                Button("..") {
                    navigateUp()
                }
            }
            
            ForEach(viewModel.currentItems) { item in
                HStack {
                    Image(systemName: item.type == .directory ? "folder" : "doc")
                    
                    VStack(alignment: .leading) {
                        Text(item.name)
                        if let size = item.size {
                            Text("\(size) bytes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onTapGesture {
                    if item.type == .directory {
                        navigateToDirectory(item.name)
                    } else {
                        handleFileSelection(item)
                    }
                }
            }
        }
        .navigationTitle("Files")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Disconnect") {
                    viewModel.disconnect()
                }
            }
        }
    }
    
    private func navigateUp() {
        currentPath = (currentPath as NSString).deletingLastPathComponent
        viewModel.changeDirectory("..")  // Use wrapped method
        viewModel.requestDirectoryListing()
    }

    private func navigateToDirectory(_ name: String) {
        currentPath = (currentPath as NSString).appendingPathComponent(name)
        viewModel.changeDirectory(name)  // Use wrapped method
        viewModel.requestDirectoryListing()
    }
    
    private func handleFileSelection(_ item: FTPListItem) {
        print("Selected file: \(item.name)")
    }
}
#Preview {
    FileListView()
}
