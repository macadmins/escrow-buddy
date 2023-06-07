//
//  EBMechanism.swift
//  Escrow Buddy
//
//  Copyright 2023 Netflix
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

//  Inspired by portions of Crypt.
//  https://github.com/grahamgilbert/crypt/

import Foundation
import Security
import os.log

class EBMechanism: NSObject {
    // Log Escrow Buddy Mechanism
    private static let log = OSLog(subsystem: "com.netflix.Escrow-Buddy", category: "EBMechanism")
    // Define a pointer to the MechanismRecord. This will be used to get and set
    // all the inter-mechanism data. It is also used to allow or deny the login.
    var mechanism: UnsafePointer<MechanismRecord>

    // init the class with a MechanismRecord
    @objc init(mechanism: UnsafePointer<MechanismRecord>) {
        os_log("initWithMechanismRecord", log: EBMechanism.log, type: .default)
        self.mechanism = mechanism
    }

    // Allow the login. End of the mechanism
    func allowLogin() {
        os_log("allowLogin called", log: EBMechanism.log, type: .default)
        _ = self.mechanism.pointee.fPlugin.pointee.fCallbacks.pointee.SetResult(
            mechanism.pointee.fEngine, AuthorizationResult.allow)
        os_log("Proceeding with login", log: EBMechanism.log, type: .default)
    }

    private func getContextData(key: AuthorizationString) -> NSData? {
        os_log("getContextData called", log: EBMechanism.log, type: .default)
        var value: UnsafePointer<AuthorizationValue>?
        let data = withUnsafeMutablePointer(to: &value) { (ptr: UnsafeMutablePointer) -> NSData? in
            var flags = AuthorizationContextFlags()
            if self.mechanism.pointee.fPlugin.pointee.fCallbacks.pointee.GetContextValue(
                self.mechanism.pointee.fEngine, key, &flags, ptr) != errAuthorizationSuccess
            {
                os_log("getContextData failed", log: EBMechanism.log, type: .error)
                return nil
            }
            guard let length = ptr.pointee?.pointee.length else {
                os_log("length failed to unwrap", log: EBMechanism.log, type: .error)
                return nil
            }
            guard let buffer = ptr.pointee?.pointee.data else {
                os_log("data failed to unwrap", log: EBMechanism.log, type: .error)
                return nil
            }
            if length == 0 {
                os_log("length is 0", log: EBMechanism.log, type: .error)
                return nil
            }
            return NSData.init(bytes: buffer, length: length)
        }
        os_log("getContextData succeeded", log: EBMechanism.log, type: .default)
        return data
    }

    var username: NSString? {
        os_log("Requesting username", log: EBMechanism.log, type: .default)
        guard let data = getContextData(key: kAuthorizationEnvironmentUsername) else {
            return nil
        }
        guard
            let s = NSString.init(
                bytes: data.bytes,
                length: data.length,
                encoding: String.Encoding.utf8.rawValue)
        else { return nil }
        return s.replacingOccurrences(of: "\0", with: "") as NSString
    }

    var password: NSString? {
        os_log("Requesting password", log: EBMechanism.log, type: .default)
        guard let data = getContextData(key: kAuthorizationEnvironmentPassword) else {
            return nil
        }
        guard
            let s = NSString.init(
                bytes: data.bytes,
                length: data.length,
                encoding: String.Encoding.utf8.rawValue)
        else { return nil }
        return s.replacingOccurrences(of: "\0", with: "") as NSString
    }

    // fdesetup Errors
    private enum FileVaultError: Error {
        case fdeSetupFailed(retCode: Int32)
        case outputPlistNull
        case outputPlistMalformed
    }

    // Check if some information on filevault whether it's encrypted and if decrypting.
    func getFVEnabled() -> (encrypted: Bool, decrypting: Bool) {
        os_log("Getting FileVault status", log: EBMechanism.log, type: .default)
        let task = Process()
        task.launchPath = "/usr/bin/fdesetup"
        task.arguments = ["status"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output: String = String(data: data, encoding: String.Encoding.utf8)
        else { return (false, false) }
        if (output.range(of: "FileVault is On.")) != nil {
            os_log("FileVault is ON", log: EBMechanism.log, type: .default)
            return (true, false)
        } else if output.range(of: "Decryption in progress:") != nil {
            os_log("FileVault is DECRYPTING", log: EBMechanism.log, type: .error)
            return (true, true)
        } else {
            os_log("FileVault is OFF", log: EBMechanism.log, type: .error)
            return (false, false)
        }
    }

    func getFVEscrowInfo() -> (location: String, forced: Bool) {
        let bundleid: CFString = "com.apple.security.FDERecoveryKeyEscrow" as CFString
        let forced: Bool = CFPreferencesAppValueIsForced("Location" as CFString, bundleid)
        guard
            let location: String = CFPreferencesCopyAppValue("Location" as CFString, bundleid)
                as? String
        else { return ("(No Location Description)", forced) }
        return (location, forced)
    }
}
