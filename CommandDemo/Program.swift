//
//  Program.swift
//  CommandDemo
//
//  Created by HIROKI IKEUCHI on 2023/06/30.
//

import Foundation

struct Program {
    let projectFile: URL
    let scheme: String
    var configuration = "Release"
}

extension Program {
    // ビルド結果の出力先ディレクトリ
    // 変更方法ある？
    var buildDirectory: URL {
        projectFile.deletingLastPathComponent().appendingPathComponent("build")
    }
    
    var archiveFile: URL {
        buildDirectory
            .appendingPathComponent(scheme)
            .appendingPathExtension("xcarchive")
    }
}

// MARK: - Command

extension Program {
    
    /*
    // "xcodebuild -showsdks"で取得して使用する
    private static let sdk = "macosx13.3"
    
    var buildCommand: String {
"""
xcodebuild \
 -target \(target) \
 -project \(projectFile.path) \
 -configuration \(configuration) \
-sdk \(Self.sdk) \
build
"""
    }
     */
    
    var commandForArchive: String {
"""
xcodebuild \
-scheme "\(scheme)" \
-project "\(projectFile.path)" \
-destination "generic/platform=macOS" \
-configuration "\(configuration)" \
-archivePath "\(archiveFile.path)" \
archive
"""
    }
    
    var commandForExportArchive: String {
"""
xcodebuild \
-exportArchive \
-archivePath  "\(archiveFile.path)" \
-exportPath "\(buildDirectory.path)" \
-exportOptionsPlist "\(archiveFile.path)/Info.plist"
"""
    }
}

extension Program {
    static let sampleData: [Program] = [
        .init(projectFile: URL(fileURLWithPath: "/Users/ikeh/Downloads/tmp/BuildSampleProject/BuildSampleProject.xcodeproj"), scheme: "BuildSampleProject"),
        .init(projectFile: URL(fileURLWithPath: "/Users/ikeh/Downloads/tmp/BuildSampleProject2/BuildSampleProject2.xcodeproj"), scheme: "BuildSampleProject2"),
        .init(projectFile: URL(fileURLWithPath: "/Users/ikeh/Downloads/tmp/BuildSampleProject3/BuildSampleProject3.xcodeproj"), scheme: "BuildSampleProject3"),
    ]
}
