//
//  MasterViewController.swift
//  RealmDo
//
//  Created by Nguyen Trong Bang on 9/10/17.
//  Copyright © 2017 Nguyen Trong Bang. All rights reserved.
//

import UIKit
import RealmSwift


class MasterViewController: UITableViewController {

    @IBOutlet weak var addButton: UIBarButtonItem!
    
    var realm: Realm!
    var realmNotiToken: NotificationToken?
    var realmCollectionNotiToken: NotificationToken?
    
    var remindersList: Results<Reminder>?
    
    func loadData() -> Results<Reminder> {
            let results = realm.objects(Reminder.self)
            return results
        
        
        
            self.realmCollectionNotiToken = results.addNotificationBlock({[weak self] (changes: RealmCollectionChange<Results<Reminder>>) in
                print("Realm collection changed!")
                guard let me = self else {return}
                
                switch changes {
                case .initial:
                    print("Realm Initial")
                case .update( let results , let deletions, let insertions, let updates):
                    print("Realm update: \(results.count)")
                    let fromRow = { (row: Int) in return IndexPath(row: row, section: 0) }
                    
#if true
                        me.tableView.reloadData()
#else
                    me.tableView.beginUpdates()
                    me.tableView.insertRows(at: insertions.map(fromRow), with: .automatic)
                    me.tableView.reloadRows(at: updates.map(fromRow), with: .automatic)
                    me.tableView.deleteRows(at: deletions.map(fromRow), with: .automatic)
                    me.tableView.endUpdates()
#endif
                case .error(let error): fatalError("\(error)")
                }
            })
            return results
    }
    
    var detailViewController: DetailViewController? = nil

    deinit {
        print("\(#function)")
        realmNotiToken?.stop()
        self.realmCollectionNotiToken?.stop()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
#if true //set DB configuration
        let path = NSTemporaryDirectory().appending("/db.realm")
        Realm.Configuration.defaultConfiguration = Realm.Configuration(fileURL: URL(fileURLWithPath: path),
                                            inMemoryIdentifier: nil,
                                            syncConfiguration: nil,
                                            encryptionKey: nil,
                                            readOnly: false,
                                            schemaVersion: 4,
                                            migrationBlock: { (migration, ver) in
                                                print("Migrating")
        }, deleteRealmIfMigrationNeeded: false,
           shouldCompactOnLaunch: nil,
           objectTypes: nil)
#endif
        realm = try! Realm() //use default config
        remindersList = loadData()
#if false
        realmNotiToken = realm.addNotificationBlock {[weak self] (noti: Realm.Notification, rlm: Realm) in
            print("Something changed in Realm database!")
            guard let me = self else {return}
            me.tableView.reloadData()
        }
#endif
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        testInsetDBTime()
        //testRelationship()
    }
    
    func testInsetDBTime() {
        print("Start insret test")
        let NUM_WRITE_TEST = 10000 //Even ok with 200k, but can't compare with Coredata because Coredata takes hours
        
        var startTime = CFAbsoluteTimeGetCurrent()
        guard let realmInstance = self.realm else {return}
        
        try! realmInstance.write {
            realmInstance.delete(realmInstance.objects(Reminder.self))
        }
        var arr: [Reminder] = []
        for _ in 1...NUM_WRITE_TEST {
            let reminderItem = Reminder()
            reminderItem.name = "Item Name"
            reminderItem.name1 = "Item Name"
            reminderItem.name2 = "Item Name"
            reminderItem.name3 = "Item Name"
            reminderItem.name4 = "Item Name"
            reminderItem.name5 = "Item Name"
            reminderItem.name6 = "Item Name"
            reminderItem.name7 = "Item Name"
            reminderItem.name8 = "Item Name"
            reminderItem.name9 = "Item Name"
            reminderItem.name10 = "Item Name"
            reminderItem.done = false
            
            arr.append(reminderItem)
        }
        try! realmInstance.write({
            realmInstance.add(arr)
        })
        print("Finished write after: \(CFAbsoluteTimeGetCurrent() - startTime)")
        startTime = CFAbsoluteTimeGetCurrent()
        
        let results = realmInstance.objects(Reminder.self);
        let str: NSMutableString = NSMutableString()
        for i in 1...NUM_WRITE_TEST {
            str.append(results[i-1].name)
        }
        print("Finish read after: \(CFAbsoluteTimeGetCurrent() - startTime)")
        
        //Test allocating mem to see how memcache work
        allocUntilDie()
        
        //self.tableView.reloadData()
    }
    
    func allocUntilDie() {
        var numMB: Int = 0;
        while true {
            allocateMemoryOfSize(numberOfMegaBytes: 2)
            numMB += 2
            print("Allocated: \(numMB) MB")
        }
    }
    
    //Call after write & read DB, to check how mem cache work
    func allocateMemoryOfSize(numberOfMegaBytes: Int) {
        print("Allocating \(numberOfMegaBytes)MB of memory")
        let mb = 1048576
        let numberOfBytes = numberOfMegaBytes * mb
        var newBuffer = [UInt8](repeating: 0, count: numberOfBytes)
        
        for i in 0 ..< numberOfBytes {
            newBuffer[i] = UInt8(i % 7)
        }
        print("Finished allocating")
    }
    
    func testInsertItemsToDBMultiThread() {
        DispatchQueue.global(qos: .background).async {
            for i in 1...1000 {
                let reminderItem = Reminder()
                reminderItem.name = "Item Name"
                reminderItem.done = false
                
                //Realm Object can't be use cross thread. But it's fast to init a new object because it was cache inside Realm
                let realmPerThread = try! Realm()
                
                try! realmPerThread.write({
                    realmPerThread.add(reminderItem)
                })
                print("Added object: \(i)")
            }
        }
    }
    
    func testDeleteItemsInDBMultiThread() {
        DispatchQueue.global(qos: .background).async {
            for i in 1...1000 {
                
                //Realm Object can't be use cross thread. But it's fast to init a new object because it was cache inside Realm
                let realmPerThread = try! Realm()
                let results = realmPerThread.objects(Reminder.self)
                if results.count > 0 {
                    let idx = Int(arc4random_uniform(UInt32(results.count)))
                    print("idx: \(idx) / \(results.count)")
                    let item = results[idx]
                    try! realmPerThread.write {
                        realmPerThread.delete(item)
                    }
                    print("Delete Realm item: \(i)")
                }
            }
        }
    }
    
    func testRelationship() {
        guard let realmInstance = self.realm else {return}
        
        let dog1 = Dog()
        dog1.name = "Dog 1"
        
        let dog2 = Dog()
        dog2.name = "Dog 2"
        
        let person = Person()
        person.name = "Apple"
        person.dogs.append(dog1)
        person.dogs.append(dog2)
        
        try! realmInstance.write {
            realmInstance.add(person)
            realmInstance.add(dog1)
            realmInstance.add(dog2)
        }
        
        let dogs = realmInstance.objects(Dog.self)
        let persons = realmInstance.objects(Person.self)
        print("Relationship: \(persons), \(dogs)")
    }
    
    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let list = remindersList {
            return list.count
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        guard let list = remindersList else {
            return cell
        }
        
        let item = list[indexPath.row]
        cell.textLabel!.text = item.date.description
        cell.textLabel!.textColor = item.done ? UIColor.lightGray : UIColor.black
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard let list = remindersList else {return}
            let item = list[indexPath.row]
            try! self.realm.write {
                self.realm.delete(item)
            }
            //tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let list = remindersList else {return}
        let item = list[indexPath.row]
        try! realm.write ({
            item.done = !item.done
        })
        //refresh row
        //tableView.reloadRows(at: [indexPath], with: .automatic)
    }
    
    
    @IBAction func addReminder(_ sender: Any) {
        
#if false //Show Dialog to input
        let alertVC : UIAlertController = UIAlertController(title: "New Reminder", message: "What do you want to remember?", preferredStyle: .alert)
        
        alertVC.addTextField { (UITextField) in
            
        }
        
        let cancelAction = UIAlertAction.init(title: "Cancel", style: .destructive, handler: nil)
        
        alertVC.addAction(cancelAction)
        
        //Alert action closure
        let addAction = UIAlertAction.init(title: "Add", style: .default) { (UIAlertAction) -> Void in
            
            guard let realmMainInstance = self.realm else {return}
            
            let textFieldReminder = (alertVC.textFields?.first)! as UITextField
            let reminderItem = Reminder()       // (8)
            reminderItem.name = textFieldReminder.text!
            reminderItem.done = false
            
            // We are adding the reminder to our database
            try! realmMainInstance.write({
                realmMainInstance.add(reminderItem)    // (9)
                
                //self.tableView.insertRows(at: [IndexPath.init(row: self.remindersList.count-1, section: 0)], with: .automatic)
            })
        }
        
        alertVC.addAction(addAction)
        
        present(alertVC, animated: true, completion: nil)
#else
    guard let realmMainInstance = self.realm else {return}
    let reminderItem = Reminder()
    reminderItem.name = "Reminder item"
    reminderItem.done = false
    try! realmMainInstance.write({
        realmMainInstance.add(reminderItem)
    })
#endif
    }
    
}

