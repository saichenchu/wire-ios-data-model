//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


import Foundation
import ZMProtos

extension Cache {
    
    /// Decrypts an encrypted asset in the asset cache to a decrypted version in the cache. Upon completion of the decryption, deletes the encrypted
    /// original. In case of error (the digest doesn't match, or any other error), deletes the original and does not create a decrypted version.
    /// Returns whether the decryption was successful and the digest matched
    func decryptAssetIfItMatchesDigest(_ plaintextEntryKey: String, encryptedEntryKey: String, encryptionKey: Data, macKey: Data, macDigest: Data) -> Bool {
        let encryptedData = self.assetData(encryptedEntryKey)
        if encryptedData == nil {
            return false
        }
        
        let mac = encryptedData!.zmHMACSHA256Digest(key: macKey)
        if mac != macDigest {
            self.deleteAssetData(encryptedEntryKey)
            return false
        }
        let plainData = encryptedData!.zmDecryptPrefixedPlainTextIV(key: encryptionKey)
        if let plainData = plainData {
            self.storeAssetData(plainData, key: plaintextEntryKey)
        }
        self.deleteAssetData(encryptedEntryKey)
        return true
    }
    
    /// Decrypts an encrypted asset in the asset cache to a decrypted version in the cache. Upon completion of the decryption, deletes the encrypted
    /// original. In case of error (the digest doesn't match, or any other error), deletes the original and does not create a decrypted version.
    /// Returns whether the decryption was successful and the digest matched
    func decryptAssetIfItMatchesDigest(_ plaintextEntryKey: String, encryptedEntryKey: String, encryptionKey: Data, sha256Digest: Data) -> Bool {
        let encryptedData = self.assetData(encryptedEntryKey)
        if encryptedData == nil {
            return false
        }
        
        let sha256 = encryptedData!.zmSHA256Digest()
        if sha256 != sha256Digest {
            self.deleteAssetData(encryptedEntryKey)
            return false
        }
        let plainData = encryptedData!.zmDecryptPrefixedPlainTextIV(key: encryptionKey)
        if let plainData = plainData {
            self.storeAssetData(plainData, key: plaintextEntryKey)
        }
        self.deleteAssetData(encryptedEntryKey)
        return true
    }
    
    /// Encrypts a plaintext cache entry to an encrypted one, also computing the digest of the encrypted entry
    func encryptFileAndComputeSHA256Digest(_ plaintextEntryKey: String, encryptedEntryKey: String) -> ZMImageAssetEncryptionKeys? {
        guard let plainData = self.assetData(plaintextEntryKey) else {
            return nil
        }
        
        let encryptionKey = Data.randomEncryptionKey()
        let encryptedData = plainData.zmEncryptPrefixingPlainTextIV(key: encryptionKey)
        let hash = encryptedData.zmSHA256Digest()
        self.storeAssetData(encryptedData, key: encryptedEntryKey)
        
        return ZMImageAssetEncryptionKeys(otrKey: encryptionKey, sha256: hash)
    }
}

extension ImageAssetCache {
    
    /// Decrypts an encrypted asset in the asset cache to a decrypted version in the cache. Upon completion of the decryption, deletes the encrypted
    /// original. In case of error (the digest doesn't match, or any other error), deletes the original and does not create a decrypted version.
    /// Returns whether the decryption was successful and the digest matched
    public func decryptAssetIfItMatchesDigest(_ nonce: UUID, format: ZMImageFormat, encryptionKey: Data, macKey: Data, macDigest: Data) -> Bool {
        let plaintextCacheKey = type(of: self).cacheKeyForAsset(nonce, format: format, encrypted: false)
        let encryptedCacheKey = type(of: self).cacheKeyForAsset(nonce, format: format, encrypted: true)
        return self.cache.decryptAssetIfItMatchesDigest(plaintextCacheKey, encryptedEntryKey: encryptedCacheKey, encryptionKey: encryptionKey, macKey: macKey, macDigest: macDigest)
    }
    
    /// Decrypts an encrypted asset in the asset cache to a decrypted version in the cache. Upon completion of the decryption, deletes the encrypted
    /// original. In case of error (the digest doesn't match, or any other error), deletes the original and does not create a decrypted version.
    /// Returns whether the decryption was successful and the digest matched
    public func decryptFileIfItMatchesDigest(_ nonce: UUID, format: ZMImageFormat, encryptionKey: Data, sha256Digest: Data) -> Bool {
        let plaintextCacheKey = type(of: self).cacheKeyForAsset(nonce, format: format, encrypted: false)
        let encryptedCacheKey = type(of: self).cacheKeyForAsset(nonce, format: format, encrypted: true)
        return self.cache.decryptAssetIfItMatchesDigest(plaintextCacheKey, encryptedEntryKey: encryptedCacheKey, encryptionKey: encryptionKey, sha256Digest: sha256Digest)
    }
    
    /// Encrypts a plaintext cache entry to an encrypted one, also computing the digest of the encrypted entry
    public func encryptFileAndComputeSHA256Digest(_ nonce: UUID, format: ZMImageFormat) -> ZMImageAssetEncryptionKeys? {
        let plaintextCacheKey = type(of: self).cacheKeyForAsset(nonce, format: format, encrypted: false)
        let encryptedCacheKey = type(of: self).cacheKeyForAsset(nonce, format: format, encrypted: true)
        return self.cache.encryptFileAndComputeSHA256Digest(plaintextCacheKey, encryptedEntryKey: encryptedCacheKey)
    }
}

extension FileAssetCache {
    
    /// Decrypts an encrypted asset in the asset cache to a decrypted version in the cache. Upon completion of the decryption, deletes the encrypted
    /// original. In case of error (the digest doesn't match, or any other error), deletes the original and does not create a decrypted version.
    /// Returns whether the decryption was successful and the digest matched
    public func decryptAssetIfItMatchesDigest(_ nonce: UUID, fileName: String, encryptionKey: Data, macKey: Data, macDigest: Data) -> Bool {
        let plaintextCacheKey = type(of: self).cacheKeyForAsset(nonce, suffix: fileName, encrypted: false)
        let encryptedCacheKey = type(of: self).cacheKeyForAsset(nonce, suffix: fileName, encrypted: true)
        return self.cache.decryptAssetIfItMatchesDigest(plaintextCacheKey, encryptedEntryKey: encryptedCacheKey, encryptionKey: encryptionKey, macKey: macKey, macDigest: macDigest)
    }
    
    /// Decrypts an encrypted asset in the asset cache to a decrypted version in the cache. Upon completion of the decryption, deletes the encrypted
    /// original. In case of error (the digest doesn't match, or any other error), deletes the original and does not create a decrypted version.
    /// Returns whether the decryption was successful and the digest matched
    public func decryptFileIfItMatchesDigest(_ nonce: UUID, fileName: String, encryptionKey: Data, sha256Digest: Data) -> Bool {
        let plaintextCacheKey = type(of: self).cacheKeyForAsset(nonce, suffix: fileName, encrypted: false)
        let encryptedCacheKey = type(of: self).cacheKeyForAsset(nonce, suffix: fileName, encrypted: true)
        return self.cache.decryptAssetIfItMatchesDigest(plaintextCacheKey, encryptedEntryKey: encryptedCacheKey, encryptionKey: encryptionKey, sha256Digest: sha256Digest)
    }
    
    /// Encrypts a plaintext cache entry to an encrypted one, also computing the digest of the encrypted entry
    public func encryptFileAndComputeSHA256Digest(_ nonce: UUID, fileName: String) -> ZMImageAssetEncryptionKeys? {
        let plaintextCacheKey = type(of: self).cacheKeyForAsset(nonce, suffix: fileName, encrypted: false)
        let encryptedCacheKey = type(of: self).cacheKeyForAsset(nonce, suffix: fileName, encrypted: true)
        return self.cache.encryptFileAndComputeSHA256Digest(plaintextCacheKey, encryptedEntryKey: encryptedCacheKey)
    }
}
