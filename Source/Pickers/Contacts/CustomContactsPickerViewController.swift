import UIKit
import ContactsUI

extension UIAlertController {
    
    /// Add Contacts Picker
    ///
    /// - Parameters:
    ///   - selection: action for selection of contact
    
    public func addCustomContactsPicker(localizer: TelegramPickerResourceProvider? = nil, buttonTitle:String, contacts: [Contact], selection: @escaping CustomContactsPickerViewController.Selection) {
        let selection: CustomContactsPickerViewController.Selection = selection
        var contact: Contact?
        
        let addContact = UIAlertAction(title: buttonTitle, style: .default) { action in
            selection(contact)
        }
        addContact.isEnabled = false
        
        let vc = CustomContactsPickerViewController.init(selection: { (new) in
            addContact.isEnabled = new != nil
            contact = new
        }, contacts: contacts)
        
        set(vc: vc)
        addAction(addContact)
    }
}

final public class CustomContactsPickerViewController: UIViewController {
    
    // MARK: UI Metrics
    
    struct UI {
        static let rowHeight: CGFloat = 58
        static let separatorColor: UIColor = UIColor.lightGray.withAlphaComponent(0.4)
    }
    
    // MARK: Properties
    
    public typealias Selection = (Contact?) -> ()
    
    fileprivate var selection: Selection?
    
    //Contacts ordered in dicitonary alphabetically
    fileprivate var contacts: [Contact]
    fileprivate var orderedContacts = [String: [Contact]]()
    fileprivate var sortedContactKeys = [String]()
    
    fileprivate var selectedContact: Contact?
    
    fileprivate lazy var tableView: UITableView = { [unowned self] in
        $0.dataSource = self
        $0.delegate = self
        //$0.allowsMultipleSelection = true
        $0.rowHeight = UI.rowHeight
        $0.separatorColor = UI.separatorColor
        $0.bounces = true
        $0.backgroundColor = nil
        $0.tableFooterView = UIView()
        $0.sectionIndexBackgroundColor = .clear
        $0.sectionIndexTrackingBackgroundColor = .clear
        $0.register(ContactTableViewCell.self,
                    forCellReuseIdentifier: ContactTableViewCell.identifier)
        return $0
        }(UITableView(frame: .zero, style: .plain))
    
    // MARK: Initialize
    
    required public init(selection: Selection?, contacts: [Contact]) {
        self.selection = selection
        self.contacts = contacts
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // http://stackoverflow.com/questions/32675001/uisearchcontroller-warning-attempting-to-load-the-view-of-a-view-controller/
        Log("has deinitialized")
    }
    
    override public func loadView() {
        view = tableView
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            preferredContentSize.width = UIScreen.main.bounds.width / 2
        }
        
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .bottom
        definesPresentationContext = true

        updateContacts()
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.tableHeaderView?.frame.size.height = 57
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preferredContentSize.height = tableView.contentSize.height
        Log("preferredContentSize.height = \(preferredContentSize.height), tableView.contentSize.height = \(tableView.contentSize.height)")
    }
    
    func updateContacts() {
        
        self.orderedContacts[""] = contacts
        self.sortedContactKeys = Array(self.orderedContacts.keys).sorted(by: <)
        
        if self.sortedContactKeys.first == "#" {
            self.sortedContactKeys.removeFirst()
            self.sortedContactKeys.append("#")
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func contact(at indexPath: IndexPath) -> Contact? {
        let key: String = sortedContactKeys[indexPath.section]
        if let contact = orderedContacts[key]?[indexPath.row] {
            return contact
        }
        return nil
    }
    
    func indexPathOfSelectedContact() -> IndexPath? {
        guard let selectedContact = selectedContact else { return nil }
        for section in 0 ..< sortedContactKeys.count {
            if let orderedContacts = orderedContacts[sortedContactKeys[section]] {
                for row in 0 ..< orderedContacts.count {
                    if orderedContacts[row].id == selectedContact.id {
                        return IndexPath(row: row, section: section)
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - TableViewDelegate

extension CustomContactsPickerViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let contact = contact(at: indexPath) else { return }
        selectedContact = contact
        Log(selectedContact?.displayName)
        selection?(selectedContact)
    }
}

// MARK: - TableViewDataSource

extension CustomContactsPickerViewController: UITableViewDataSource {
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return sortedContactKeys.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let contactsForSection = orderedContacts[sortedContactKeys[section]] {
            return contactsForSection.count
        }
        return 0
    }
    
    public func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        tableView.scrollToRow(at: IndexPath(row: 0, section: index), at: .top , animated: false)
        return sortedContactKeys.firstIndex(of: title)!
    }
    
    public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sortedContactKeys
    }
    
    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sortedContactKeys[section]
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.identifier) as! ContactTableViewCell
       
        guard let contact = contact(at: indexPath) else { return UITableViewCell() }
        
        if let selectedContact = selectedContact, selectedContact.value == contact.value {
            cell.setSelected(true, animated: true)
            Log("indexPath = \(indexPath) is selected - \(contact.displayName) = \(cell.isSelected)")
            //cell.isSelected = true
        }
        
        cell.configure(with: contact)
        return cell
    }
}
