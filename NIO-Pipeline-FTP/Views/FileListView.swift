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
    @State private var isDownloading = false
    @State private var showDownloadStatus = false
    @State private var downloadStatusMessage = ""
    
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
                    
                    if item.type == .file {
                        Spacer()
                        if isDownloading {
                            ProgressView()
                        } else {
                            Button(action: { handleFileSelection(item) }) {
                                Image(systemName: "arrow.down.circle")
                            }
                        }
                    }
                }
                .onTapGesture {
                    if item.type == .directory {
                        navigateToDirectory(item.name)
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
        .alert("Download Status", isPresented: $showDownloadStatus) {
            Button("OK") {}
        } message: {
            Text(downloadStatusMessage)
        }
    }
    
    private func navigateUp() {
        currentPath = (currentPath as NSString).deletingLastPathComponent
        viewModel.changeDirectory("..")
        viewModel.requestDirectoryListing()
    }

    private func navigateToDirectory(_ name: String) {
        currentPath = (currentPath as NSString).appendingPathComponent(name)
        viewModel.changeDirectory(name)
        viewModel.requestDirectoryListing()
    }
    
    private func handleFileSelection(_ item: FTPListItem) {
        isDownloading = true
        // TODO: real async downloads
        Task {
            // fake download time
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            await MainActor.run {
                isDownloading = false
                downloadStatusMessage = "Successfully downloaded \(item.name)"
                showDownloadStatus = true
            }
        }
    }
}

#Preview {
    FileListView()
}
