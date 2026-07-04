//
//  SimpodHelper.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/9/26.
//
import Foundation
import CoreVideo
import CoreMedia
import AppKit
import ArgumentParser

@main
struct SimpodHelper: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simpod-helper-bin",
        abstract: "Simpod simulator helper"
    )
    
    @Argument(help: "Simulator UDID")
    var udid: String
    
    @Option(name: .long, help: "Host to bind to")
    var host: String = "0.0.0.0"
    
    @Option(name: .long, help: "Port to listen on")
    var port: Int = 5400
    
    func run() async throws {
        // stdout is a pipe when the CLI spawns us, which makes `print` fully
        // buffered — session logs would arrive in 4KB bursts. Line-buffer so
        // the server can forward log lines as they happen.
        setlinebuf(stdout)
        _ = await MainActor.run {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        let server = HTTPServer(udid: udid, port: port, host: host)
        try await server.start()
    }
}
