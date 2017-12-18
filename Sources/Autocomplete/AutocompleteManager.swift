//
//  AttachmentManager.swift
//  InputBarAccessoryView
//
//  Copyright © 2017 Nathan Tannar.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//
//  Created by Nathan Tannar on 10/4/17.
//

import UIKit

open class AutocompleteManager: NSObject {
    
    open weak var dataSource: AutocompleteManagerDataSource?
    
    open weak var delegate: AutocompleteManagerDelegate?
    
    private(set) public weak var inputTextView: InputTextView?
    
    /// The autocomplete table for prefixes
    open lazy var tableView: AutocompleteTableView = {
        let tableView = AutocompleteTableView()
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()
    
    /// If the autocomplete matches should be made by casting the strings to lowercase
    open var isCaseSensitive = false
    
    /// The maximum number of visible rows in the `tableView` before the user has to scroll throught them.
    open var maximumVisibleRows: Double {
        get { return self.tableView.maximumVisibleRows }
        set { self.tableView.maximumVisibleRows = newValue }
    }
    
    /// The prefixes that the manager will recognize
    open var autocompletePrefixes: [Character] = []
    
    /// The default text attributes
    open var defaultTextAttributes: [NSAttributedStringKey:Any] = [
        .font : UIFont.preferredFont(forTextStyle: .body),
        .foregroundColor : UIColor.black
    ]
    
    /// The text attributes applied to highlighted substrings for each prefix
    open var highlightedTextAttributes: [Character: [NSAttributedStringKey: Any]] = [
        "@": [.foregroundColor : UIColor(red: 0, green: 122/255, blue: 1, alpha: 1),
              .backgroundColor : UIColor(red: 0, green: 122/255, blue: 1, alpha: 0.1)]
    ]
    
    fileprivate(set) open var foundPrefix: Character?
    fileprivate(set) open var foundPrefixRange: Range<Int>?
    fileprivate(set) open var foundWord: String? {
        didSet {
            tableView.reloadData()
            tableView.invalidateIntrinsicContentSize()
            tableView.superview?.layoutIfNeeded()
        }
    }
    
    private var highlightedSubstrings = [Character:[String]]()
    
    // MARK: - Initialization
    
    public init(for textView: InputTextView) {
        super.init()
        self.inputTextView = textView
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.textViewTextDidChangeNotification(_:)), name: .UITextViewTextDidChange, object: textView)
    }
}


// MARK: - InputManager
extension AutocompleteManager: InputManager {
    
    open func reload() {
        processTextForAutoCompletion()
        highlightSubstrings()
    }
    
    open func invalidate() {
        unregisterCurrentPrefix()
    }
    
    open func handleInput(of object: AnyObject) {
        guard let newText = object as? String, let textView = inputTextView else { return }
        let newAttributedString = NSMutableAttributedString(attributedString: textView.attributedText).normal(newText)
        textView.attributedText = newAttributedString
        reload()
    }
}

// MARK: - Autocomplete
fileprivate extension AutocompleteManager {
    
    func registerCurrentPrefix(to prefix: Character, at range: Range<Int>, word: String) {
        defer {
            delegate?.autocompleteManager(self, shouldBecomeVisible: true)
        }
        guard delegate?.autocompleteManager(self, shouldRegister: prefix, at: range) != false else {
            return
        }
        (foundPrefix, foundPrefixRange, foundWord) = (prefix, range, word)
    }
    
    func unregisterCurrentPrefix() {
        defer {
            delegate?.autocompleteManager(self, shouldBecomeVisible: false)
        }
        guard let prefix = foundPrefix,
            delegate?.autocompleteManager(self, shouldUnregister: prefix) != false
            else { return }
        
        (foundPrefixRange, foundPrefix, foundWord) = (nil, nil, nil)
    }
    
    /// Replaces the current prefix and filter text with the supplied text
    ///
    /// - Parameters:
    ///   - text: The replacement text
    public func autocomplete(with text: String) {
        guard let textView = inputTextView,
            let prefix = foundPrefix,
            let prefixRange = foundPrefixRange,
            let foundWord = foundWord else { return }
        
        guard delegate?.autocompleteManager(self, shouldComplete: prefix, with: text) != false else { return }
        
        // Appending a space should dismiss the auto complete
        let textToInsert = text + " "
//        let filterText = "\(prefix)\(foundWord)"
        
        // Calculate the range to replace
//        guard let leftIndex = textView.text.index(textView.text.startIndex, offsetBy: prefixRange.lowerBound, limitedBy: textView.text.endIndex),
//            let rightIndex = textView.text.index(leftIndex, offsetBy: prefixRange.upperBound + foundWord.count, limitedBy: textView.text.endIndex)
//            else { return }
        
//        let range = leftIndex...rightIndex
        
        // Insert the text
        let range = NSMakeRange(prefixRange.lowerBound, String(prefix).count + foundWord.count)
        textView.text = (textView.text as? NSString)?.replacingCharacters(in: range, with: textToInsert)
        textView.messageInputBar?.textViewDidChange()
//        textView.text.removeSubrange(range).replaceSubrange(range, with: textToInsert)
        
        // Apply the highlight attributes
        highlightSubstrings()
        
        // Move Cursor to the end of the inserted text
        textView.selectedRange = NSMakeRange(range.location + textToInsert.count, 0)
        
        // Unregister
        unregisterCurrentPrefix()
    }
    
    private func processTextForAutoCompletion() {
        
        inputTextView?.lookFor(prefixes: Set(autocompletePrefixes)) { (prefix, word) in
            guard let prefix = prefix, let word = word else {
                unregisterCurrentPrefix()
                (foundPrefix, foundWord, foundPrefixRange) = (nil, nil, nil)
                return
            }
            let prefixLength = String(prefix).count
            let range = Range(NSMakeRange(word.range.location, prefixLength))!
            let cleanedWord = String(word.text.dropFirst(prefixLength))
            
            // Handle word
            
            if handleProcessedWord(word, prefix: prefix, range: range) {
                registerCurrentPrefix(to: prefix, at: range, word: cleanedWord)
            } else {
                unregisterCurrentPrefix()
            }
        }
    }
    
    private func handleProcessedWord(_ word: AutocompleteTextInput.Word, prefix: Character, range: Range<Int>) -> Bool {
        guard let textView = inputTextView,
            
            // Cancel auto-completion if the cursor is placed before the prefix
            textView.selectedRange.lowerBound >= range.lowerBound,
            
            // Make sure that the word has the appropriate length
            word.range.length > 0
            else {
                return false
        }
        
        let show = dataSource?.autocompleteManager(self, didChangeAutoCompletionPrefix: prefix, prefixRange: range, word: word.text)
        return show ?? false
    }
}

// MARK: - UITableViewDataSource
extension AutocompleteManager: UITableViewDataSource {
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let dataSource = dataSource else {
            fatalError("No `dataSource` has been set")
        }
        guard let prefix = foundPrefix else { return 0 }
        return dataSource.autocompleteManager(self, numberOfRowsInSection: section, prefix: prefix)
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let prefix = foundPrefix else { return UITableViewCell() }
        
        guard let cell = dataSource?.autocompleteManager(self, tableView: tableView, cellForRowAt: indexPath, for: prefix) else {
            fatalError("Method not implemented")
        }
        return cell
    }
}

// MARK: - UITableViewDelegate
extension AutocompleteManager: UITableViewDelegate {
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let prefix = foundPrefix,
        let text = delegate?.autocompleteManager(self, didSelectRowAt: indexPath, prefix: prefix)
            else { return }
        
        autocomplete(with: String(prefix) + text)
    }
}

// MARK: - Text Highlighting
extension AutocompleteManager {
    
    /// Resets the InputTextViews typingAttributes to defaultTextAttributes
    open func resetTypingAttributes() {
        
        var typingAttributes = [String:Any]()
        defaultTextAttributes.forEach { typingAttributes[$0.key.rawValue] = $0.value }
        inputTextView?.typingAttributes = typingAttributes
    }
    
    /// Applies highlighting to substrings that begin with a registered prefix
    open func highlightSubstrings() {
        guard let textView = inputTextView else { return }
        
        let attributedString = NSMutableAttributedString(string: textView.text, attributes: defaultTextAttributes)
        
        // Get the substrings with a prefix
        let substrings = textView.text
            .components(separatedBy: .whitespaces)
            .filter {
                guard let prefix = $0.first, $0.count > 1 else { return false }
                guard self.highlightedTextAttributes[prefix] != nil else { return false } // if there are no custom attributes
                return self.autocompletePrefixes.contains(prefix)
        }
        
        // Calculate the NSRange of each substring
        substrings.forEach { substring in
            var ranges = [NSRange]()
            var searchStartIndex = textView.text.startIndex
            while searchStartIndex < textView.text.endIndex, let range = textView.text.range(of: substring, range: searchStartIndex..<textView.text.endIndex), !range.isEmpty {
                
                let utf16 = textView.text.utf16
                if let from = range.lowerBound.samePosition(in: utf16), let to = range.upperBound.samePosition(in: utf16) {
                    let nsrange = NSRange(location: utf16.distance(from: utf16.startIndex, to: from),
                                          length: utf16.distance(from: from, to: to))
                    ranges.append(nsrange)
                }
                searchStartIndex = range.upperBound
            }
            // Apply the attributes
            if let prefix = substring.first, let textAttributes = self.highlightedTextAttributes[prefix] {
                ranges.forEach { attributedString.addAttributes(textAttributes, range: $0) }
            }
        }
        
        // Set the new attributed string
        textView.attributedText = attributedString
    }
}


// MARK: - Helpers
fileprivate extension AutocompleteManager {
    
    /// A safe way to generate an offset to the current prefix
    ///
    /// - Returns: An offset that is not more than the endIndex or less than the startIndex
    func safeOffset(withText text: String) -> Int {
        guard let range = foundPrefixRange, text.count > 0 else { return 0 }
        return max(min(0, range.lowerBound), text.count - 1)
    }
}


// MARK: - Notification Center
extension AutocompleteManager {
    
    @objc func textViewTextDidChangeNotification(_ note: Notification) {
        
        // Ensure that the text to be inserted is not using previous attributes
        resetTypingAttributes()
        
        // Process text
        processTextForAutoCompletion()
    }
}
