//
//  InteractionViewModel.swift
//  Interaction
//
//  Created by Marco Mascorro on 9/1/23.
//

import NearbyInteraction
import MultipeerConnectivity

import Combine
import Foundation
import SwiftUI

class InteractionViewModel: NSObject, ObservableObject {
    @Published var invitationClosed = false
    @Published var peerName = ""
    @Published var distanceToPeer: Float?
    @Published var isDirectionAvailable = false
    @Published var directionAngle = 0.0
    @Published var isConnectionLost = false
    @Published var userID: String = ""
    @AppStorage("local_uid") var deviceId: String = ""
    @Published var otherId = ""

    private var nearbySession: NISession?
    private let serviceIdentity: String
    private var multipeerSession: MCSession?
    private var peer: MCPeerID?
    private var peerToken: NIDiscoveryToken?
    private var multipeerAdvertiser: MCNearbyServiceAdvertiser?
    private var multipeerBrowser: MCNearbyServiceBrowser?
    private var maxPeersInSession = 1
    private var sharedTokenWithPeer = false

    static var nearbySessionAvailable: Bool {
        return NISession.isSupported
    }

    func currentDevice() {
        let id = UUID().uuidString
        deviceId = id
    }

    override internal init() {
        #if targetEnvironment(simulator)
        self.serviceIdentity = "xyz.eliat.Interaction./simulator_ni"
        #else
        self.serviceIdentity = "xyz.eliat.Interaction./device_ni"
        #endif
        
        super.init()
        self.startNearbySession()
        self.startMultipeerSession()
        self.currentDevice()
    }

    deinit {
        self.stopMultipeerSession()
        self.multipeerSession?.disconnect()
    }

    internal func startNearbySession() -> Void {
        self.nearbySession = NISession()
        self.nearbySession?.delegate = self
        sharedTokenWithPeer = false
        
        if self.peer != nil && self.multipeerSession != nil {
            if !self.sharedTokenWithPeer {
                shareTokenWithAllPeers()
            }
        } else {
            self.startMultipeerSession()
        }
    }

    private func startMultipeerSession() -> Void {
        if self.multipeerSession == nil {
            let localPeer = MCPeerID(displayName: UIDevice.current.name)
            self.multipeerSession = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
            self.multipeerAdvertiser = MCNearbyServiceAdvertiser(peer: localPeer, discoveryInfo: ["identity": serviceIdentity], serviceType: "interaction")
            self.multipeerBrowser = MCNearbyServiceBrowser(peer: localPeer, serviceType: "interaction")
            self.multipeerSession?.delegate = self
            self.multipeerAdvertiser?.delegate = self
            self.multipeerBrowser?.delegate = self
        }
        
        self.stopMultipeerSession()
        self.multipeerAdvertiser?.startAdvertisingPeer()
        self.multipeerBrowser?.startBrowsingForPeers()
    }

    private func stopMultipeerSession() -> Void {
        self.multipeerAdvertiser?.stopAdvertisingPeer()
        self.multipeerBrowser?.stopBrowsingForPeers()
    }

    private func shareTokenWithAllPeers() -> Void {
        guard let token = nearbySession?.discoveryToken,
              let multipeerSession = self.multipeerSession,
              let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        else {
            fatalError("😭")
        }
        
        do {
            try self.multipeerSession?.send(encodedData, toPeers: multipeerSession.connectedPeers, with: .reliable)
        } catch let error {
            print("Token cannot be sent. \(error.localizedDescription)")
        }
        
        self.sharedTokenWithPeer = true
    }

    private func sendDeviceIdToPeers() {
            guard let multipeerSession = self.multipeerSession,
                  let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: deviceId, requiringSecureCoding: true)
            else {
                fatalError("😭")
            }

            do {
                try multipeerSession.send(encodedData, toPeers: multipeerSession.connectedPeers, with: .reliable)
            } catch let error {
                print("Device ID cannot be sent. \(error.localizedDescription)")
            }
        }
}

extension InteractionViewModel: NISessionDelegate {
    func session(_ session: NISession, didInvalidateWith error: Error) -> Void {
        self.startNearbySession()
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) -> Void {
        session.invalidate()
        self.startNearbySession()
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) -> Void {
        guard let nearbyObject = nearbyObjects.first else {
            return
        }
        
        self.distanceToPeer = nearbyObject.distance
        
        if let direction = nearbyObject.direction {
            self.isDirectionAvailable = true
            self.directionAngle = direction.x > 0.0 ? 90.0 : -90.0
        } else {
            self.isDirectionAvailable = false
        }
    }

    func sessionSuspensionEnded(_ session: NISession) -> Void {
        guard let peerToken = self.peerToken else {
            return
        }
        
        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        self.nearbySession?.run(config)
        self.shareTokenWithAllPeers()
    }

    func sessionWasSuspended(_ session: NISession) -> Void {
        print("\(#function). Ill be back... 🙋‍♂️")
    }
}

extension InteractionViewModel: MCSessionDelegate {
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print("\(#function)")
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print("\(#function)")
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print("\(#function)")
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.peerName = peerID.displayName
                self.peer = peerID
                self.shareTokenWithAllPeers()
                self.isConnectionLost = false
                self.sendDeviceIdToPeers()
            case .notConnected:
                self.isConnectionLost = true
            case .connecting:
                self.peerName = "Hello, who are you? 👋"
            @unknown default:
                fatalError("Error")
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard peerID.displayName == self.peerName else {
            return
        }
        
        do {
            guard let discoveryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
                print("Unarchiving failed: Discovery token not valid")
                return
            }
            
            let config = NINearbyPeerConfiguration(peerToken: discoveryToken)
            self.nearbySession?.run(config)
            self.peerToken = discoveryToken
            
            DispatchQueue.main.async {
                self.isConnectionLost = false
            }
        } catch let error {
            print("Unarchiving error:", error)
        }
    }
}

extension InteractionViewModel: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        guard let multipeerSession = self.multipeerSession else {
            return
        }
        
        if multipeerSession.connectedPeers.count < self.maxPeersInSession {
            invitationHandler(true, multipeerSession)
        }
    }
}

extension InteractionViewModel: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if self.peerName == peerID.displayName {
            self.isConnectionLost = true
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) -> Void {
        guard let info = info, let identity = info["identity"], let multipeerSession = self.multipeerSession,
              (identity == self.serviceIdentity && multipeerSession.connectedPeers.count < self.maxPeersInSession) else {
            return
        }
        
        browser.invitePeer(peerID, to: multipeerSession, withContext: nil, timeout: 10)
    }
}
