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
@testable import ZMCDataModel

class ConversationObserverTests : NotificationDispatcherTestBase {
    
    
    func checkThatItNotifiesTheObserverOfAChange(_ conversation : ZMConversation,
                                                 modifier: (ZMConversation, ConversationObserver) -> Void,
                                                 expectedChangedField : String?,
                                                 expectedChangedKeys: KeySet,
                                                 file: StaticString = #file,
                                                 line: UInt = #line) {
        
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: modifier,
                                                     expectedChangedFields: expectedChangedField != nil ? KeySet(key: expectedChangedField!) : KeySet(),
                                                     expectedChangedKeys: expectedChangedKeys,
                                                     file: file,
                                                     line: line)
    }
    
    var conversationInfoKeys : [String] {
        return [
            "messagesChanged",
            "participantsChanged",
            "nameChanged",
            "lastModifiedDateChanged",
            "unreadCountChanged",
            "connectionStateChanged",
            "isArchivedChanged",
            "isSilencedChanged",
            "conversationListIndicatorChanged",
            "clearedChanged",
            "securityLevelChanged",
            "callParticipantsChanged",
            "videoParticipantsChanged"
        ]
    }
    
    func checkThatItNotifiesTheObserverOfAChange(_ conversation : ZMConversation,
                                                 modifier: (ZMConversation, ConversationObserver) -> Void,
                                                 expectedChangedFields : KeySet,
                                                 expectedChangedKeys: KeySet,
                                                 file: StaticString = #file,
                                                 line: UInt = #line) {
        
        // given
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: conversation)
        
        // when
        modifier(conversation, observer)
        conversation.managedObjectContext!.saveOrRollback()
        
        // then
        let changeCount = observer.notifications.count
        if !expectedChangedFields.isEmpty {
            XCTAssertEqual(changeCount, 1, "Observer expected 1 notification, but received \(changeCount).", file: file, line: line)
        } else {
            XCTAssertEqual(changeCount, 0, "Observer was notified, but DID NOT expect a notification", file: file, line: line)
        }
        
        // and when
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.notifications.count, changeCount, "Should have changed only once", file: file, line: line)
        
        if expectedChangedFields.isEmpty {
            return
        }
        
        if let changes = observer.notifications.first {
            checkChangeInfoContainsExpectedKeys(changes: changes, expectedChangedFields: expectedChangedFields, expectedChangedKeys: expectedChangedKeys, file: file, line: line)
        }
        
        ConversationChangeInfo.remove(observer:token, for: conversation)
    }
    
    func checkChangeInfoContainsExpectedKeys(changes: ConversationChangeInfo,
                                             expectedChangedFields : KeySet,
                                             expectedChangedKeys: KeySet,
                                             file: StaticString = #file,
                                             line: UInt = #line){
        for key in conversationInfoKeys {
            if expectedChangedFields.contains(key) {
                if let value = changes.value(forKey: key) as? NSNumber {
                    XCTAssertTrue(value.boolValue, "\(key) was supposed to be true", file: file, line: line)
                }
                continue
            }
            if let value = changes.value(forKey: key) as? NSNumber {
                XCTAssertFalse(value.boolValue, "\(key) was supposed to be false", file: file, line: line)
            }
            else {
                XCTFail("Can't find key or key is not boolean for '\(key)'", file: file, line: line)
            }
        }
        XCTAssertEqual(KeySet(Array(changes.changedKeys)), expectedChangedKeys, file: file, line: line)
    }
    
    
    func testThatItNotifiesTheObserverOfANameChange()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        conversation.userDefinedName = "George"
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.userDefinedName = "Phil"},
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
        
    }
    
    func notifyNameChange(_ user: ZMUser, name: String) {
        user.name = name
        self.uiMOC.saveOrRollback()
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseOfActiveParticipants()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
        otherUser.name = "Foo"
        conversation.mutableOtherActiveParticipants.add(otherUser)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        self.notifyNameChange(otherUser, name: "Phil")
            },
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
        
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseAnActiveParticipantWasAdded()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        
                                                        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
                                                        otherUser.name = "Foo"
                                                        conversation.mutableOtherActiveParticipants.add(otherUser)
            },
                                                     expectedChangedFields: KeySet(["nameChanged", "participantsChanged"]),
                                                     expectedChangedKeys: KeySet(["displayName", "otherActiveParticipants"])
        )
        
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseOfActiveParticipantsMultipleTimes()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let user = ZMUser.insertNewObject(in:self.uiMOC)
        conversation.mutableOtherActiveParticipants.add(user)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: conversation)
        
        // when
        user.name = "Boo"
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(observer.notifications.count, 1)
        
        // and when
        user.name = "Bar"
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // then
        XCTAssertEqual(observer.notifications.count, 2)
        
        // and when
        self.uiMOC.saveOrRollback()
        ConversationChangeInfo.remove(observer:token, for: conversation)
    }
    
    
    func testThatItDoesNotNotifyTheObserverBecauseAUsersAccentColorChanged()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
        otherUser.accentColorValue = .brightOrange
        conversation.mutableOtherActiveParticipants.add(otherUser)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        otherUser.accentColorValue = ZMAccentColor.softPink
            },
                                                     expectedChangedField: nil,
                                                     expectedChangedKeys: KeySet()
        )
    }
    
    func testThatItNotifiesTheObserverOfANameChangeBecauseOfOtherUserNameChange()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .oneOnOne
        
        let otherUser = ZMUser.insertNewObject(in:self.uiMOC)
        otherUser.name = "Foo"
        
        let connection = ZMConnection.insertNewObject(in: self.uiMOC)
        connection.to = otherUser
        connection.status = .accepted
        conversation.connection = connection
        
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { _ in
                                                        self.notifyNameChange(otherUser, name: "Phil")
            },
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
        
    }
    
    
    
    func testThatItNotifysTheObserverOfANameChangeBecauseAUserWasAddedLaterAndHisNameChanged()
    {
        // given
        let user1 = ZMUser.insertNewObject(in:self.uiMOC)
        user1.name = "Foo A"
        
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        XCTAssertTrue(user1.displayName == "Foo")
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, observer in
                                                        conversation.mutableOtherActiveParticipants.add(user1)
                                                        self.uiMOC.saveOrRollback()
                                                        observer.clearNotifications()
                                                        self.notifyNameChange(user1, name: "Bar")
            },
                                                     expectedChangedField: "nameChanged",
                                                     expectedChangedKeys: KeySet(["displayName"])
        )
    }
    
    func testThatItNotifiesTheObserverOfAnInsertedMessage()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.lastReadServerTimeStamp = Date()
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        _ = conversation.appendMessage(withText: "foo")
            },
                                                     expectedChangedField: "messagesChanged",
                                                     expectedChangedKeys: KeySet(key: "messages"))
    }
    
    func testThatItNotifiesTheObserverOfAnAddedParticipant()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let user = ZMUser.insertNewObject(in:self.uiMOC)
        user.name = "Foo"
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.mutableOtherActiveParticipants.add(user) },
                                                     expectedChangedFields: KeySet(["participantsChanged", "nameChanged"]),
                                                     expectedChangedKeys: KeySet(["displayName", "otherActiveParticipants"]))
        
    }
    
    func testThatItNotifiesTheObserverOfAnRemovedParticipant()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        let user = ZMUser.insertNewObject(in:self.uiMOC)
        user.name = "bar"
        conversation.mutableOtherActiveParticipants.add(user)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: {conversation, _ in conversation.mutableOtherActiveParticipants.remove(user) },
                                                     expectedChangedFields: KeySet(["participantsChanged", "nameChanged"]),
                                                     expectedChangedKeys: KeySet(["displayName", "otherActiveParticipants"]))
    }
    
    func testThatItNotifiesTheObserverIfTheSelfUserIsAdded()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        conversation.isSelfAnActiveMember = false
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: {conversation, _ in conversation.isSelfAnActiveMember = true },
                                                     expectedChangedField: "participantsChanged",
                                                     expectedChangedKeys: KeySet(key: "isSelfAnActiveMember"))
        
    }
    
    func testThatItNotifiesTheObserverWhenTheUserLeavesTheConversation()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        _ = ZMUser.insertNewObject(in:self.uiMOC)
        conversation.isSelfAnActiveMember = true
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: {conversation, _ in conversation.isSelfAnActiveMember = false },
                                                     expectedChangedField: "participantsChanged",
                                                     expectedChangedKeys: KeySet(key: "isSelfAnActiveMember"))
        
    }
    
    func testThatItNotifiesTheObserverOfChangedLastModifiedDate()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.lastModifiedDate = Date() },
                                                     expectedChangedField: "lastModifiedDateChanged",
                                                     expectedChangedKeys: KeySet(key: "lastModifiedDate"))
        
    }
    
    func testThatItNotifiesTheObserverOfChangedUnreadCount()
    {
        // given
        let uiConversation : ZMConversation = ZMConversation.insertNewObject(in:self.uiMOC)
        uiConversation.lastReadServerTimeStamp = Date()
        uiConversation.userDefinedName = "foo"
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        var conversation : ZMConversation!
        var message : ZMMessage!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = self.syncMOC.object(with: uiConversation.objectID) as! ZMConversation
            message = ZMMessage.insertNewObject(in: self.syncMOC)
            message.visibleInConversation = conversation
            message.serverTimestamp = conversation.lastReadServerTimeStamp?.addingTimeInterval(10)
            self.syncMOC.saveOrRollback()
            
            conversation.didUpdateWhileFetchingUnreadMessages()
            self.syncMOC.saveOrRollback()
            XCTAssertEqual(conversation.estimatedUnreadCount, 1)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mergeLastChanges()
        
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: uiConversation)
        
        // when
        self.syncMOC.performGroupedBlockAndWait {
            conversation.lastReadServerTimeStamp = message.serverTimestamp
            conversation.updateUnread()
            XCTAssertEqual(conversation.estimatedUnreadCount, 0)
            self.syncMOC.saveOrRollback()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mergeLastChanges()
        
        // then
        let changeCount = observer.notifications.count
        XCTAssertEqual(changeCount, 1, "Observer expected 1 notification, but received \(changeCount).")
        
        guard let changes = observer.notifications.first else { return XCTFail() }
        checkChangeInfoContainsExpectedKeys(changes: changes,
                                            expectedChangedFields: KeySet(["unreadCountChanged", "conversationListIndicatorChanged"]),
                                            expectedChangedKeys: KeySet(["estimatedUnreadCount", "conversationListIndicator"]))
        
        ConversationChangeInfo.remove(observer:token, for: conversation)
    }
    
    func testThatItNotifiesTheObserverOfChangedDisplayName()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.group
        uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.userDefinedName = "Cacao" },
                                                     expectedChangedField: "nameChanged" ,
                                                     expectedChangedKeys: KeySet(["displayName"]))
        
    }
    
    func testThatItNotifiesTheObserverOfChangedConnectionStatusWhenInsertingAConnection()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.oneOnOne
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        conversation.connection = ZMConnection.insertNewObject(in: self.uiMOC)
                                                        conversation.connection!.status = ZMConnectionStatus.pending
            },
                                                     expectedChangedField: "connectionStateChanged" ,
                                                     expectedChangedKeys: KeySet(key: "relatedConnectionState"))
    }
    
    func testThatItNotifiesTheObserverOfChangedConnectionStatusWhenUpdatingAConnection()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = ZMConversationType.oneOnOne
        conversation.connection = ZMConnection.insertNewObject(in: self.uiMOC)
        conversation.connection!.status = ZMConnectionStatus.pending
        conversation.connection!.to = ZMUser.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.connection!.status = ZMConnectionStatus.accepted },
                                                     expectedChangedField: "connectionStateChanged" ,
                                                     expectedChangedKeys: KeySet(key: "relatedConnectionState"))
        
    }
    
    
    func testThatItNotifiesTheObserverOfChangedArchivedStatus()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.isArchived = true },
                                                     expectedChangedField: "isArchivedChanged" ,
                                                     expectedChangedKeys: KeySet(["isArchived"]))
        
    }
    
    func testThatItNotifiesTheObserverOfChangedSilencedStatus()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in conversation.isSilenced = true },
                                                     expectedChangedField: "isSilencedChanged" ,
                                                     expectedChangedKeys: KeySet(key: "isSilenced"))
        
    }
    
    func addUnreadMissedCall(_ conversation: ZMConversation) {
        let systemMessage = ZMSystemMessage.insertNewObject(in: conversation.managedObjectContext!)
        systemMessage.systemMessageType = .missedCall;
        systemMessage.serverTimestamp = Date(timeIntervalSince1970:1231234)
        systemMessage.visibleInConversation = conversation
        conversation.updateUnreadMessages(with: systemMessage)
    }
    
    
    func testThatItNotifiesTheObserverOfAChangedListIndicatorBecauseOfAnUnreadMissedCall()
    {
        // given
        let uiConversation : ZMConversation = ZMConversation.insertNewObject(in:self.uiMOC)
        uiConversation.userDefinedName = "foo"
        uiMOC.saveOrRollback()
        
        var conversation : ZMConversation!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = self.syncMOC.object(with: uiConversation.objectID) as! ZMConversation
            self.syncMOC.saveOrRollback()
        }

        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: uiConversation)
        
        // when
        self.syncMOC.performGroupedBlockAndWait {
            self.addUnreadMissedCall(conversation)
            self.syncMOC.saveOrRollback()
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        mergeLastChanges()
                
        // then
        let changeCount = observer.notifications.count
        XCTAssertEqual(changeCount, 1, "Observer expected 1 notification, but received \(changeCount).")
        
        guard let changes = observer.notifications.first else { return XCTFail() }
        checkChangeInfoContainsExpectedKeys(changes: changes,
                                            expectedChangedFields: KeySet(["conversationListIndicatorChanged", "messagesChanged"]),
                                            expectedChangedKeys: KeySet(["messages", "conversationListIndicator"]))
        
        ConversationChangeInfo.remove(observer:token, for: conversation)
        
    }
    
    func testThatItNotifiesTheObserverOfAChangedClearedTimeStamp()
    {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        conversation.clearedTimeStamp = Date()
            },
                                                     expectedChangedField: "clearedChanged" ,
                                                     expectedChangedKeys: KeySet(key: "clearedTimeStamp"))
    }
    
    func testThatItNotifiesTheObserverOfASecurityLevelChange() {
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        conversation.securityLevel = .secure
            },
                                                     expectedChangedField: "securityLevelChanged" ,
                                                     expectedChangedKeys: KeySet(key: "securityLevel"))
    }
    
    func testThatItNotifiesAboutSecurityLevelChange_AddingParticipant(){
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.conversationType = .group
        conversation.securityLevel = .secure
        self.uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        let user = ZMUser.insertNewObject(in: self.uiMOC)
                                                        conversation.addParticipant(user)
        },
                                                     expectedChangedFields: KeySet(["securityLevelChanged", "messagesChanged", "nameChanged", "participantsChanged"]),
                                                     expectedChangedKeys: KeySet(["displayName", "messages", "otherActiveParticipants", "securityLevel"]))
    
    }
    
    func testThatItNotifiesAboutSecurityLevelChange_AddingDevice(){
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        let user = ZMUser.insertNewObject(in: self.uiMOC)

        conversation.conversationType = .group
        conversation.securityLevel = .secure
        self.uiMOC.saveOrRollback()
        
        // when
        self.checkThatItNotifiesTheObserverOfAChange(conversation,
                                                     modifier: { conversation, _ in
                                                        let client = UserClient.insertNewObject(in: self.uiMOC)
                                                        client.remoteIdentifier = "aabbccdd";
                                                        client.user = user;

                                                        conversation.decreaseSecurityLevelIfNeededAfterDiscovering(clients: [client], causedBy: nil)

        },
                                                     expectedChangedFields: KeySet(["securityLevelChanged", "messagesChanged"]),
                                                     expectedChangedKeys: KeySet(["securityLevel", "messages"]))
        
    }
    
    func testThatItNotifiesAboutSecurityLevelChange_SendingMessageToDegradedConversation(){
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        conversation.securityLevel = .secureWithIgnored
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: conversation)
        
        // when
        conversation.appendMessage(withText: "Foo")
        self.uiMOC.saveOrRollback()
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // then
        XCTAssertEqual(observer.notifications.count, 2)
        
        guard let first = observer.notifications.first, let second = observer.notifications.last else { return }
        
        // We get two notifications - one for messages added and another for non-core data change
        let messagesNotification = first.messagesChanged ? first : second
        let securityNotification = first.securityLevelChanged ? first : second
        
        XCTAssertTrue(messagesNotification.messagesChanged)
        XCTAssertTrue(securityNotification.securityLevelChanged)

        ConversationChangeInfo.remove(observer:token, for: conversation)
    }
    
    func testThatItStopsNotifyingAfterUnregisteringTheToken() {
        
        // given
        let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        let observer = ConversationObserver()
        let token = ConversationChangeInfo.add(observer: observer, for: conversation)
        ConversationChangeInfo.remove(observer:token, for: conversation)
        
        
        // when
        conversation.userDefinedName = "Mario!"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.notifications.count, 0)
    }
}

// MARK: Performance

extension ConversationObserverTests {
    
    func testPerformanceOfCalculatingChangeNotificationsWhenUserChangesName()
    {
        // average: 0.056, relative standard deviation: 2.400%, values: [0.056840, 0.054732, 0.059911, 0.056330, 0.055015, 0.055535, 0.055917, 0.056481, 0.056177, 0.056115]
        // 13/02/17 average: 0.049, relative standard deviation: 4.095%, values: [0.052629, 0.046448, 0.046743, 0.047157, 0.051125, 0.048899, 0.047646, 0.048362, 0.048110, 0.051135]
        let count = 50
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            let user = ZMUser.insertNewObject(in: self.uiMOC)
            user.name = "foo"
            let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
            conversation.conversationType = .group
            conversation.mutableOtherActiveParticipants.add(user)
            self.uiMOC.saveOrRollback()
            
            let observer = ConversationObserver()
            let token = ConversationChangeInfo.add(observer: observer, for: conversation)
            
            var lastName = "bar"
            self.startMeasuring()
            for _ in 1...count {
                let temp = lastName
                lastName = user.name
                user.name = temp
                self.uiMOC.saveOrRollback()
            }
            XCTAssertEqual(observer.notifications.count, count)
            self.stopMeasuring()
            ConversationChangeInfo.remove(observer:token, for: conversation)
        }
    }


    func testPerformanceOfCalculatingChangeNotificationsWhenANewMessageArrives()
    {
       // average: 0.059, relative standard deviation: 13.343%, values: [0.082006, 0.056299, 0.056005, 0.056230, 0.059868, 0.055533, 0.055511, 0.055503, 0.055434, 0.055458]
        // 13/02/17: average: 0.062, relative standard deviation: 10.863%, values: [0.082063, 0.059699, 0.059220, 0.059861, 0.060348, 0.059494, 0.064300, 0.060022, 0.058819, 0.058870]
        let count = 50
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
            self.uiMOC.saveOrRollback()
            
            let observer = ConversationObserver()
            let token = ConversationChangeInfo.add(observer: observer, for: conversation)
            
            self.startMeasuring()
            for _ in 1...count {
                conversation.appendMessage(withText: "hello")
                self.uiMOC.saveOrRollback()
            }
            XCTAssertEqual(observer.notifications.count, count)
            self.stopMeasuring()
            ConversationChangeInfo.remove(observer:token, for: conversation)
        }
    }
    
    func testPerformanceOfCalculatingChangeNotificationsWhenANewMessageArrives_AppendingManyMessages()
    {
        // 50: average: 0.026, relative standard deviation: 29.098%, values: [0.047283, 0.023655, 0.024622, 0.025462, 0.029163, 0.024709, 0.024966, 0.020773, 0.020413, 0.019464],
        // 500: average: 0.243, relative standard deviation: 4.039%, values: [0.264489, 0.235209, 0.245864, 0.244984, 0.231789, 0.244359, 0.251886, 0.229036, 0.247700, 0.239637],
        
        // 13/02/17 - 50 : average: 0.023, relative standard deviation: 27.833%, values: [0.041493, 0.020441, 0.020226, 0.020104, 0.021268, 0.021039, 0.020917, 0.020330, 0.020558, 0.019953]
        let count = 50
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
            self.uiMOC.saveOrRollback()
            
            let observer = ConversationObserver()
            let token = ConversationChangeInfo.add(observer: observer, for: conversation)
            
            self.startMeasuring()
            for _ in 1...count {
                conversation.appendMessage(withText: "hello")
            }
            self.uiMOC.saveOrRollback()
            XCTAssertEqual(observer.notifications.count, 1)
            self.stopMeasuring()
            ConversationChangeInfo.remove(observer:token, for: conversation)
        }
    }
    
    func testPerformanceOfCalculatingChangeNotificationsWhenANewMessageArrives_RegisteringNewObservers()
    {
       // 50: average: 0.093, relative standard deviation: 9.576%, values: [0.119425, 0.091509, 0.088228, 0.090549, 0.090424, 0.086471, 0.091216, 0.091060, 0.094097, 0.089602],
        // 500: average: 0.886, relative standard deviation: 1.875%, values: [0.922453, 0.878736, 0.880529, 0.899234, 0.875889, 0.904563, 0.890234, 0.872045, 0.868912, 0.871016]
        // 500: after adding convList observer average: 1.167, relative standard deviation: 9.521%, values: [1.041614, 1.020351, 1.055602, 1.098007, 1.129816, 1.166439, 1.221696, 1.293128, 1.314360, 1.331703], --> growing due to additional conversation observers
        // 500: after forwarding conversation changes: average: 0.941, relative standard deviation: 2.144%, values: [0.991118, 0.956727, 0.947056, 0.928683, 0.937171, 0.947680, 0.928902, 0.925021, 0.923206, 0.922440] --> constant! yay!
        // 13/02/17 50: average: 0.104, relative standard deviation: 10.316%, values: [0.134496, 0.097219, 0.106044, 0.100265, 0.098114, 0.097030, 0.105297, 0.099680, 0.098974, 0.099365]
        
        let count = 50
        
        self.measureMetrics([XCTPerformanceMetric_WallClockTime], automaticallyStartMeasuring: false) {
            
            let observer = ConversationObserver()
            
            self.startMeasuring()
            for _ in 1...count {
                let conversation = ZMConversation.insertNewObject(in:self.uiMOC)
                self.uiMOC.saveOrRollback()
                let token = ConversationChangeInfo.add(observer: observer, for: conversation)
                conversation.appendMessage(withText: "hello")
                self.uiMOC.saveOrRollback()
                ConversationChangeInfo.remove(observer:token, for: conversation)

            }
            self.stopMeasuring()
        }
    }
}

