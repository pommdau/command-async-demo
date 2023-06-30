//
//  Command.swift
//  CommandDemo
//
//  Created by HIROKI IKEUCHI on 2023/06/30.
//

import Foundation

// MARK: - Command Error

enum CommandError: Error {
    case cancel(String)  // Taskがキャンセルされた
    case failedInRunning  // process.run()でエラーが発生
    case exitStatusIsInvalid(Int32, String) // 終了ステータスが0以外
}

extension CommandError: LocalizedError {
    // error.localizedDescriptionで表示される内容
    var errorDescription: String? {
        switch self {
        case .cancel(let output):
            return "処理をキャンセルしました。\n標準出力: \(output)"
        case .failedInRunning:
            return "コマンドの実行時にエラーが発生しました"
        case .exitStatusIsInvalid(let status, let output):
            return
"""
コマンドの実行が正常に完了しませんでした。\n\
終了コード: \(status)\n\
標準出力: \(output)
"""
        }
    }
}

struct Command {
    
    @discardableResult
    static func execute(command: String, currentDirectoryURL: URL? = nil) async throws -> String {
        
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-cl", command]
        process.currentDirectoryURL = currentDirectoryURL
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
        } catch {
            throw CommandError.failedInRunning
        }
        
        var standardOutput = ""
        // Processが完了するまで、Taskがキャンセルされていないかを監視
        while process.isRunning {
            do {
                try Task.checkCancellation()
            } catch {
                process.terminate()
                throw CommandError.cancel(standardOutput)  // キャンセル途中までのの標準出力を返す
            }
            // readDataToEndOfFile()ではpingなどのキャンセル時に途中経過が取得できないのでavailableDataを使用
            let data = pipe.fileHandleForReading.availableData
            if data.count > 0,
               let _standardOutput = String(data:  data, encoding: .utf8) {
                standardOutput += _standardOutput
            }
            try? await Task.sleep(nanoseconds: 0_500_000_000)  // wait 0.5s
        }
        
        // 残りの標準出力の取得
        if let _data = try? pipe.fileHandleForReading.readToEnd(),
           let _standardOutput = String(data: _data, encoding: .utf8) {
            standardOutput += _standardOutput
        }
        
        try? await Task.sleep(nanoseconds: 0_500_000_000)  // wait 0.5s
        if process.terminationStatus != 0 {
            throw CommandError.exitStatusIsInvalid(process.terminationStatus, standardOutput)
        }
                        
        return standardOutput
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
