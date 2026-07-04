//
//  Stream.swift
//  SimpodHelper
//
//  Created by Tomiwa Idowu on 6/11/26.
//

protocol Stream {
    func start(frameCapture: SimulatorFrameCapture) throws
    
    func stop()
    

    func requestKeyframe()

    func requestSnapshot()
}
