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
    var wordAtCaret: AutocompleteTextInput.Word? { get }
}

// MARK: - AutocompleteTextInput
extension UITextView: AutocompleteTextInput {
    
    // -----------------------------------
    // MARK: - Public Methods
    
    public func lookFor(prefixes: Set<Character>, completionHandler: (Character?, AutocompleteTextInput.Word?) -> Void) {
        guard prefixes.count > 0,
            let result = wordAtCaret,
            !result.text.isEmpty
            else {
                completionHandler(nil, nil)
                return
        }
        for prefix in prefixes {
            if result.text.hasPrefix(String(prefix)) {
                let word = Word(result.text, result.range)
                completionHandler(prefix, word)
            }
        }
    }
    
    public var wordAtCaret: AutocompleteTextInput.Word? {
        guard let caretRange = self.caretRange,
            let result = text.word(at: caretRange)
            else { return nil }
        
        let location = result.range.lowerBound.encodedOffset
        let range = NSRange(location: location, length: result.range.upperBound.encodedOffset - location)
        
        return (result.word, range)
    }
    
    var caretRange: NSRange? {
        guard let selectedRange = self.selectedTextRange else { return nil }
        return NSRange(
            location: offset(from: beginningOfDocument, to: selectedRange.start),
            length: offset(from: selectedRange.start, to: selectedRange.end)
        )
    }
}
