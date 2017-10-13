//
//  Models.swift
//  RealmDo
//
//  Created by Nguyen Trong Bang on 12/10/17.
//  Copyright © 2017 Nguyen Trong Bang. All rights reserved.
//

import Foundation
import RealmSwift

class Dog: Object {
    @objc dynamic var uuid = UUID().uuidString
    @objc dynamic var name: String?
    let owner = LinkingObjects(fromType: Person.self, property: "dogs")
    override static func primaryKey() -> String {
        return "uuid"
    }
}

class Person: Object {
    @objc dynamic var uuid = UUID().uuidString
    @objc dynamic var name: String?
    //@objc dynamic var dogs: [Dog] = []
    let dogs = List<Dog>()
    
    override static func primaryKey() -> String {
        return "uuid"
    }
}
