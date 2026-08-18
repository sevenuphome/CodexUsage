import Foundation
import CloudKit

/// Mac → iPhone bridge: the Mac app publishes the latest Codex snapshot into
/// the CloudKit private database; the iOS app and widget fetch it. One
/// record, always overwritten in place. (Same pattern as ClaudeUsage.)
enum CodexCloud {
    static let containerID = "iCloud.com.ekkasit.CodexUsage"

    private static var database: CKDatabase {
        CKContainer(identifier: containerID).privateCloudDatabase
    }
    private static let recordID = CKRecord.ID(recordName: "current")

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// Mac side: push the latest snapshot.
    static func publish(_ snapshot: CodexSnapshot) async throws {
        let payload = try encoder.encode(snapshot)
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "Usage", recordID: recordID)
        }
        record["payload"] = String(decoding: payload, as: UTF8.self)
        record["updatedAt"] = Date()
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
    }

    struct Fetched {
        let snapshot: CodexSnapshot
        let published: Date
    }

    /// iOS side: pull the latest snapshot. nil = Mac has never published.
    static func fetch() async throws -> Fetched? {
        do {
            let record = try await database.record(for: recordID)
            guard let payload = record["payload"] as? String,
                  let published = record["updatedAt"] as? Date else { return nil }
            let snapshot = try decoder.decode(CodexSnapshot.self, from: Data(payload.utf8))
            return Fetched(snapshot: snapshot, published: published)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }
}
