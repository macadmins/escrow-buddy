//
//  Invoke.swift
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

import CoreFoundation
import Foundation
import Security
import os.log

class Invoke: EBMechanism {
    // Log for the Invoke functions
    private static let log = OSLog(subsystem: "com.netflix.Escrow-Buddy", category: "Invoke")

    // Preference bundle id
    fileprivate let bundleid = "com.netflix.Escrow-Buddy"

    @objc func run() {
        os_log("Starting Escrow Buddy:Invoke", log: Invoke.log, type: .default)

        // Get FileVault status
        let fdestatus = getFVEnabled()
        let fvEnabled: Bool = fdestatus.encrypted
        let decrypting: Bool = fdestatus.decrypting

        // No action needed if FileVault is off or decrypting
        if decrypting {
            os_log(
                "FileVault is decrypting", log: Invoke.log, type: .default)
            allowLogin()
            return
        }
        if !fvEnabled {
            os_log(
                "FileVault is not enabled", log: Invoke.log, type: .default)
            allowLogin()
            return
        }

        // Check for FileVault escrow profile
        let escrowInfo = getFVEscrowInfo()
        let escrowLocation = escrowInfo.location
        let escrowForced = escrowInfo.forced

        // Guard against triggering key generation without a valid escrow profile
        if !escrowForced {
            os_log(
                "ERROR: No MDM profile for enforcing FileVault escrow is present.",
                log: Invoke.log, type: .error)
            allowLogin()
            return
        } else {
            os_log(
                "FileVault configured to escrow to: %{public}@", log: Invoke.log,
                type: .default, escrowLocation)
        }

        // Get value of GenerateNewKey
        let genKey = getGenerateNewKey()
        let generateKey: Bool = genKey.generateKey
        let forcedKey: Bool = genKey.forcedKey

        // Guard against incorrect deployment of GenerateNewKey via MDM profile
        if forcedKey {
            os_log(
                "ERROR: GenerateNewKey is set by an MDM profile. This is a configuration error! Use `defaults write` to set the preference instead.",
                log: Invoke.log, type: .error)
            allowLogin()
            return
        }

        // If GenerateNewKey is False, the MDM already has a PRK escrowed for this Mac
        if !generateKey {
            os_log("GenerateNewKey is False", log: Invoke.log, type: .default)
            allowLogin()
            return
        } else {
            os_log("GenerateNewKey is True", log: Invoke.log, type: .default)
        }

        // Instantiate dictionary with credentials
        guard let username = self.username
        else {
            os_log("Unable to instantiate username", log: Invoke.log, type: .error)
            allowLogin()
            return
        }
        guard let password = self.password
        else {
            os_log("Unable to instantiate password", log: Invoke.log, type: .error)
            allowLogin()
            return
        }
        let the_settings = NSDictionary.init(dictionary: [
            "Username": username, "Password": password,
        ])

        // GenerateNewKey is True, call fdesetup to generate new recovery key
        os_log("Generating a new FileVault personal recovery key", log: Invoke.log, type: .default)
        do {
            try _ = rotateRecoveryKey(the_settings)
        } catch let error as NSError {
            os_log(
                "Caught error trying to generate a new key: %{public}@", log: Invoke.log,
                type: .error,
                error.localizedDescription)
        }

        // Cleanup after key generation
        os_log(
            "Setting GenerateNewKey to False to avoid multiple generations",
            log: Invoke.log, type: .default)
        CFPreferencesSetValue(
            "GenerateNewKey" as CFString, false as CFPropertyList, bundleid as CFString,
            kCFPreferencesAnyUser, kCFPreferencesAnyHost)
        CFPreferencesSetAppValue("GenerateNewKey" as CFString, nil, bundleid as CFString)

        allowLogin()
        return
    }

    // fdesetup Errors
    enum FileVaultError: Error {
        case fdeSetupFailed(retCode: Int32)
        case outputPlistNull
        case outputPlistMalformed
    }

    fileprivate func getGenerateNewKey() -> (generateKey: Bool, forcedKey: Bool) {
        let forcedKey: Bool = CFPreferencesAppValueIsForced(
            "GenerateNewKey" as CFString, bundleid as CFString)
        guard
            let genkey: Bool = CFPreferencesCopyAppValue(
                "GenerateNewKey" as CFString, bundleid as CFString) as? Bool
        else { return (false, forcedKey) }
        return (genkey, forcedKey)
    }

    func rotateRecoveryKey(_ theSettings: NSDictionary) throws -> Bool {
        os_log("rotateRecoveryKey called", log: Invoke.log, type: .default)
        let inputPlist = try PropertyListSerialization.data(
            fromPropertyList: theSettings,
            format: PropertyListSerialization.PropertyListFormat.xml, options: 0)

        let inPipe = Pipe.init()
        let outPipe = Pipe.init()
        let errorPipe = Pipe.init()

        let task = Process.init()
        task.launchPath = "/usr/bin/fdesetup"
        task.arguments = ["changerecovery", "-personal", "-inputplist"]
        task.standardInput = inPipe
        task.standardOutput = outPipe
        task.standardError = errorPipe
        task.launch()
        inPipe.fileHandleForWriting.write(inputPlist)
        inPipe.fileHandleForWriting.closeFile()
        task.waitUntilExit()

        let errorOut = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorMessage = String(data: errorOut, encoding: .utf8)
        errorPipe.fileHandleForReading.closeFile()

        if task.terminationStatus != 0 {
            let termstatus = String(describing: task.terminationStatus)
            os_log(
                "ERROR: fdesetup terminated with a non-zero exit status: %{public}@",
                log: Invoke.log, type: .error, termstatus)
            os_log(
                "fdesetup Standard Error: %{public}@", log: Invoke.log, type: .error,
                String(describing: errorMessage))
            throw FileVaultError.fdeSetupFailed(retCode: task.terminationStatus)
        }
        os_log("rotateRecoveryKey succeeded", log: Invoke.log, type: .default)
        return true
    }
}
