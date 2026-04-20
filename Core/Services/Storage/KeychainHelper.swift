//
//  KeychainHelper.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 19.04.2026.
//

import Foundation
import Security

final class KeychainHelper {

    static func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // удаляем старое значение
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?

        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            if let data = result as? Data,
               let string = String(data: data, encoding: .utf8) {
                return string
            }
        }

        return nil
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
