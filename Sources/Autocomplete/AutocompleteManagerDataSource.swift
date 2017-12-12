//
//  AutocompleteManagerDataSource.swift
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
//  Created by Nathan Tannar on 10/1/17.
//

import UIKit

/// AutocompleteManagerDataSource is a protocol that passes data to the AutocompleteManager
public protocol AutocompleteManagerDataSource: class {
    
    /// Notifies the `dataSource` that either the autocompletion prefix or word have changed.
    ///
    /// - Parameters:
    ///   - manager: The AutocompleteManager
    ///   - prefix: The detected prefix.
    ///   - prefixRange: The detected prefix range.
    ///   - word: The detected word.
    /// - Returns: `true` if the autocomplete view should be displayed
    func autocompleteManager(_ manager: AutocompleteManager, didChangeAutoCompletionPrefix prefix: Character, prefixRange: Range<Int>, word: String) -> Bool
    
    /// Ask the `dataSource` for the number of rows displayed in the auto complete `tableView`.
    ///
    /// - Parameters:
    ///   - manager: The AutocompleteManager instance.
    ///   - section: Section to be displayed.
    ///   - prefix: The detected prefix.
    /// - Returns: Number of rows.
    func autocompleteManager(_ manager: AutocompleteManager, numberOfRowsInSection section: Int, prefix: Character) -> Int
    
    /// The cell to populate the AutocompleteTableView with
    ///
    /// - Parameters:
    ///   - manager: The AttachmentManager
    ///   - tableView: The AttachmentManager's AutocompleteTableView
    ///   - indexPath: The indexPath of the cell
    ///   - arguments: The registered prefix and current filter text after the prefix.
    /// - Returns: A UITableViewCell to populate the AutocompleteTableView. Default is `manager.defaultCell(in: tableView, at: indexPath, for: arguments)`
    func autocompleteManager(_ manager: AutocompleteManager, tableView: UITableView, cellForRowAt indexPath: IndexPath, for prefix: Character) -> UITableViewCell
}


