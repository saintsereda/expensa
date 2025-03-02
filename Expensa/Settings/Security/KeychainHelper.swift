//
//  KeychainHelper.swift
//  Expensa
//
//  Created by Andrew Sereda on 03.11.2024.
//

import Foundation
import Security

struct KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    private let passcodeKey = "com.sereda.Expensa.passcode"  // Use a unique identifier for your app
    private let apiKey = "com.sereda.Expensa.openexchange.apikey"  // Add this

    // Save passcode to Keychain
    func savePasscode(_ passcode: String) -> Bool {
        guard let data = passcode.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey,
            kSecValueData as String: data
        ]

        // Remove any existing item before adding a new one
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // Retrieve passcode from Keychain
    func getPasscode() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data, let passcode = String(data: data, encoding: .utf8) {
            return passcode
        }
        return nil
    }

    // Delete passcode from Keychain
    func deletePasscode() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: passcodeKey
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // MARK: - API Key Methods
    func saveApiKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKey,
            kSecValueData as String: data,
            // Add additional security for API key
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Remove any existing item before adding a new one
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func getApiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }
        return nil
    }

    func deleteApiKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: apiKey
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
