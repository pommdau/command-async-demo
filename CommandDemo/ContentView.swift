/// https://tech.blog.surbiton.jp/tag/nstask/

import Foundation

struct Command {
    /// completion版
    static func execute(command: String, currentDirectoryURL: URL? = nil, completion: @escaping (Result<String, CommandError>) -> ()) {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-cl", command]
        process.launchPath = "/bin/zsh"
        process.currentDirectoryURL = currentDirectoryURL
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
        } catch {
            completion(.failure(.failedInRunning))
            return
        }
        
        var output = ""
        let saveOutputInProgress = {
            DispatchQueue.global(qos: .background).async {
                let data = pipe.fileHandleForReading.availableData  // 同スレッドで呼び出すとここでハングアップしてしまう
                if data.count > 0,
                   let _output = String(data:  data, encoding: .utf8) {
                    output += _output
                }
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Processが完了するまで、Taskがキャンセルされていないかを監視
        while process.isRunning {  // xcodebuildを呼び出した際にここがfalseにならない
            do {
                try Task.checkCancellation()
            } catch {
                process.terminate()
                completion(.failure(.cancel))
                return
            }
            saveOutputInProgress()
        }
        saveOutputInProgress()
        Thread.sleep(forTimeInterval: 0.5) // Taskの終了を待つためのDelay(必要?)
        
        if process.terminationStatus != 0 {
            completion(.failure(.exitStatusIsInvalid(process.terminationStatus, output)))
            return
        }
        print(output)
        completion(.success(output))
    }
    
    /// async版
    @discardableResult
    static func execute(command: String, currentDirectoryURL: URL? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            execute(command: command, currentDirectoryURL: currentDirectoryURL) { result in
                DispatchQueue.global(qos: .background).async {
                    do {
                        let output = try result.get()
                        continuation.resume(returning: output)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

// MARK: - Command Error

enum CommandError: Error {
    case cancel  // Taskがキャンセルされた
    case failedInRunning  // process.run()でエラーが発生
    case exitStatusIsInvalid(Int32, String) // 終了ステータスが0以外
}

extension CommandError: LocalizedError {
    
    var title: String {
        switch self {
        case .cancel:
            return "処理をキャンセルしました。"
        case .failedInRunning:
            return "コマンドの実行中にエラーが発生しました"
        case .exitStatusIsInvalid(let status, _):
            return "コマンドの実行に失敗しました。終了コード: \(status)"
        }
    }
        
    var errorDescription: String? {
        switch self {
        case .cancel, .failedInRunning:
            return nil
        case .exitStatusIsInvalid(_, let output):
            return output
        }
    }
}

// MARK: - Command + sample

extension Command {
    struct sample {
        static var echo: String {
            "echo ~'/Desktop'"
        }
        
        static var xcodebuild: String {
            """
            xcodebuild \
            -scheme "BuildSampleProject" \
            -project ~/"Downloads/tmp/BuildSampleProject/BuildSampleProject.xcodeproj" \
            -configuration "Release" \
            -archivePath ~"/Downloads/tmp/BuildSampleProject/build/BuildSampleProject.xcarchive" \
            archive
            """
        }
        
        static var ping: String {
            "ping google.co.jp"
        }
        
        static var ls: String {
            "ls -l@ ~/Desktop"
        }
    }
}

// MARK: - View

import SwiftUI

struct ContentView: View {
    
    @State var task: Task<(), Never>?
    @State var isProcessing = false
    
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
                    handleButtonClicked(command: Command.sample.xcodebuild)
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
                try await Command.execute(command: command)
            } catch {
                print(error)
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
