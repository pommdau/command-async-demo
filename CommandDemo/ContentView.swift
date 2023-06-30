/// https://tech.blog.surbiton.jp/tag/nstask/

import Foundation



// MARK: - View

import SwiftUI

struct ContentView: View {
    
    @State private var task: Task<(), Never>?
    @State private var isProcessing = false
    
    var body: some View {
        VStack {
            HStack {
                Button("echo") {
                    handleButtonClicked(command: Command.sample.echo)
                }
                Button("ping") {
                    handleButtonClicked(command: Command.sample.ping)
                }
                Button("xcodebuild") {
                    handleXcodeBuildButtonClicked()
                }
                Button("ls   ") {
                    handleButtonClicked(command: Command.sample.ls)
                }
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .frame(width: 300, height: 60)
            .disabled(isProcessing)
                                                                                                
            Button("Cancel") {
                isProcessing = false
                task?.cancel()
                task = nil
            }
            .disabled(!isProcessing)
        }
    }
    
    private func handleButtonClicked(command: String) {
        isProcessing = true
        task = Task {
            defer {
                isProcessing = false
            }
            do {
                let output = try await Command.execute(command: command)
                print(output)
            } catch {
                print(error.localizedDescription)
                return
            }
        }
    }
    
    // xcodebuildを並列に呼び出す例
    private func handleXcodeBuildButtonClicked() {
        isProcessing = true
        task = Task {
            defer {
                isProcessing = false
            }
            do {
                try await withThrowingTaskGroup(of: String.self) { group in
                    for program in Program.sampleData {
                        group.addTask {
                            return try await Command.execute(command: program.commandForArchive)
                        }
                    }
                    for try await output in group {
                        _ = output
                        print(output)
                    }
                }
            } catch {
                print(error.localizedDescription)
                return
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
