//
//  UITextInput+Autocomplete.swift
//  MessageKit
//
//  Created by Jonathan Bouaziz on 11/12/2017.
//

import Foundation

public protocol AutocompleteTextInput: UITextInput {
    
    typealias Word = (text: String, range: NSRange)
    typealias PrefixLookupCompletion = (_ prefix: Character?, _ word: Word?) -> Void
    
    /// Searches for any matching string prefix at the text input's caret position. When nothing found, the completion block returns nil values.
    /// This implementation is internally performed on a background thread and forwarded to the main thread once completed.
    ///
    /// - Parameters:
    ///   - prefixes: A set of prefixes to search for.
    ///   - completionHandler: A completion block called whenever the text processing finishes, successfuly or not.
    func lookFor(prefixes: Set<Character>, completionHandler: PrefixLookupCompletion)
    
    /// Finds the word close to the caret's position, if any.
    ///
    /// - Returns: The found word.
    func wordAtCaret() -> Word?
    
    /// Finds the word close to specific range.
    ///
    /// - Parameters: range: The range to be used for searching the word.
    /// - Returns: The found word.
    func word(at range: NSRange) -> Word?
}

// MARK: - AutocompleteTextInput
extension InputTextView: AutocompleteTextInput {
    
    // -----------------------------------
    // MARK: - Public Methods
    
    public func lookFor(prefixes: Set<Character>, completionHandler: (Character?, AutocompleteTextInput.Word?) -> Void) {
        
        // Skip when there is no prefixes to look for.
        guard prefixes.count > 0 else { return }
        
        guard let word = wordAtCaret(),
            let prefix = prefixes.first(where: { return word.text.hasPrefix(String($0)) }) else {
                completionHandler(nil, nil)
                return
        }
        var cleanedWord = word
        cleanedWord.text = String(cleanedWord.text.dropFirst(String(prefix).count))
        completionHandler(prefix, word)
    }
    
    public func wordAtCaret() -> Word? {
        guard let range = _caretRange else { return nil }
        return word(at: range)
    }
    
    public func word(at range: NSRange) -> Word? {
        
        let location = range.location
        let text = _text
        
        // Aborts in case minimum requirements are not fufilled
        guard location != NSNotFound,
            text.count > 0,
            location >= 0,
            (range.location + range.length) <= text.count else {
                return nil
        }
        
        let rightPortion = text.dropFirst(location)
        let rightComponents = rightPortion.components(separatedBy: .whitespacesAndNewlines)
        
        if location > 0,
            let rightWordPart = rightComponents.first,
            let characterBeforeCursor = rightPortion.first,
            let whitespaceRange = String(characterBeforeCursor).rangeOfCharacter(from: .whitespaces) {
            
            if whitespaceRange.isEmpty {
                
                // At the start of a word, just use the word behind the cursor for the current word
                let range = NSMakeRange(location, rightWordPart.count)
                return (rightWordPart, range)
            }
        }

        // In the middle of a word, so combine the part of the word before the cursor, and after the cursor to get the current word
        let leftPortion = text.dropLast(text.count - location)
        let leftComponents = leftPortion.components(separatedBy: .whitespacesAndNewlines)
        if let leftWordPart = leftComponents.last, let rightWordPart = rightComponents.last {
            
            var range = NSMakeRange(location-leftWordPart.count, leftWordPart.count+rightWordPart.count)
            var word = leftWordPart.appending(rightWordPart)
            let lineBreak = "\n"
            
            // If a break is detected, return the last component of the string
            if let lineBreakRange = (word as? NSString)?.range(of: lineBreak), lineBreakRange.location != NSNotFound {
                range = lineBreakRange
                word = word.components(separatedBy: lineBreak).last!
            }
            return (word, range)
        }
        return nil
    }
    
    // -----------------------------------
    // MARK: - Private helpers
    
    private var _caretRange: NSRange? {
        guard let selectedRange = selectedTextRange else {
            return nil
        }
        let beginning = beginningOfDocument
        let start = selectedRange.start
        let end = selectedRange.end
        
        let location = offset(from: beginning, to: start)
        let length = offset(from: start, to: end)
        return NSMakeRange(location, length)
    }
    
    private var _text: String {
        guard let range = textRange(from: beginningOfDocument, to: endOfDocument) else {
            return ""
        }
        return text(in: range) ?? ""
    }
}
