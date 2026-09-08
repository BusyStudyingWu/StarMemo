//
//  ContextMenu.swift
//  MarkdownEngine
//
//  Created by Luca Chen on 20.06.25.
//
//  Right-click menu with toggleable Markdown formatting actions.
//

import Cocoa
import SwiftUI

extension NativeTextViewWrapper.Coordinator {
    public func textView(_ textView: NSTextView,
                  menu: NSMenu,
                  for event: NSEvent,
                  at charIndex: Int) -> NSMenu? {
        let customMenu = menu.copy() as? NSMenu ?? NSMenu()
        insertImageAssetItemsIfNeeded(into: customMenu, textView: textView, charIndex: charIndex)

        if let fontIndex = customMenu.items.firstIndex(where: { $0.title == "Font" }) {
            customMenu.removeItem(at: fontIndex)
            let formatItem = NSMenuItem(title: "Format", action: nil, keyEquivalent: "")
            let formatSubmenu = NSMenu(title: "Format")
            let boldItem = NSMenuItem(title: "Bold", action: #selector(didMarkdownBold(_:)), keyEquivalent: "")
            boldItem.target = self
            formatSubmenu.addItem(boldItem)
            let italicItem = NSMenuItem(title: "Italic", action: #selector(didMarkdownItalic(_:)), keyEquivalent: "")
            italicItem.target = self
            formatSubmenu.addItem(italicItem)
            formatItem.submenu = formatSubmenu
            customMenu.insertItem(formatItem, at: fontIndex)

            let headingItem = NSMenuItem(title: "Heading", action: nil, keyEquivalent: "")
            let headingSubmenu = NSMenu(title: "Heading")
            for level in 1...3 {
                let item = NSMenuItem(title: "H\(level)", action: #selector(didMarkdownHeading(_:)), keyEquivalent: "")
                item.target = self
                item.tag = level
                headingSubmenu.addItem(item)
            }
            headingItem.submenu = headingSubmenu
            customMenu.insertItem(headingItem, at: fontIndex + 1)

            let listItem = NSMenuItem(title: "Lists", action: nil, keyEquivalent: "")
            let listSubmenu = NSMenu(title: "Lists")
            let unorderedItem = NSMenuItem(title: "Bullet", action: #selector(didMarkdownUnorderedList(_:)), keyEquivalent: "")
            unorderedItem.target = self
            listSubmenu.addItem(unorderedItem)
            let orderedItem = NSMenuItem(title: "Numbered", action: #selector(didMarkdownOrderedList(_:)), keyEquivalent: "")
            orderedItem.target = self
            listSubmenu.addItem(orderedItem)
            listItem.submenu = listSubmenu
            customMenu.insertItem(listItem, at: fontIndex + 2)
            customMenu.insertItem(NSMenuItem.separator(), at: fontIndex + 3)
        }

        return customMenu
    }

    private func insertImageAssetItemsIfNeeded(into menu: NSMenu, textView: NSTextView, charIndex: Int) {
        guard let provider = configuration.services.images as? any EmbeddedImageFileProvider,
              let imageReference = imageReference(at: charIndex, in: textView) else {
            return
        }

        let request = imageReference.providerRequest
        let storedURL = provider.storedFileURL(for: request)
        let originalURL = provider.originalFileURL(for: request)

        let copyImageItem = NSMenuItem(title: "复制图片", action: #selector(didCopyEmbeddedImage(_:)), keyEquivalent: "")
        copyImageItem.target = self
        copyImageItem.representedObject = request
        copyImageItem.isEnabled = configuration.services.images.image(for: request) != nil

        let copyStoredFileItem = NSMenuItem(title: "复制图片文件", action: #selector(didCopyEmbeddedImageFile(_:)), keyEquivalent: "")
        copyStoredFileItem.target = self
        copyStoredFileItem.representedObject = storedURL
        copyStoredFileItem.isEnabled = storedURL != nil

        let copyOriginalFileItem = NSMenuItem(title: "复制原始文件", action: #selector(didCopyEmbeddedImageFile(_:)), keyEquivalent: "")
        copyOriginalFileItem.target = self
        copyOriginalFileItem.representedObject = originalURL
        copyOriginalFileItem.isEnabled = originalURL != nil

        let revealStoredItem = NSMenuItem(title: "在 Finder 中显示副本", action: #selector(didRevealEmbeddedImageFile(_:)), keyEquivalent: "")
        revealStoredItem.target = self
        revealStoredItem.representedObject = storedURL
        revealStoredItem.isEnabled = storedURL != nil

        let revealOriginalItem = NSMenuItem(title: "在 Finder 中显示原始文件", action: #selector(didRevealEmbeddedImageFile(_:)), keyEquivalent: "")
        revealOriginalItem.target = self
        revealOriginalItem.representedObject = originalURL
        revealOriginalItem.isEnabled = originalURL != nil

        let copyMarkdownItem = NSMenuItem(title: "复制 Markdown 引用", action: #selector(didCopyEmbeddedImageMarkdown(_:)), keyEquivalent: "")
        copyMarkdownItem.target = self
        copyMarkdownItem.representedObject = imageReference.markdown

        [
            copyImageItem,
            copyStoredFileItem,
            copyOriginalFileItem,
            revealStoredItem,
            revealOriginalItem,
            copyMarkdownItem,
            NSMenuItem.separator()
        ].reversed().forEach { item in
            menu.insertItem(item, at: 0)
        }
    }

    private func imageReference(at charIndex: Int, in textView: NSTextView) -> ImageEmbedReference? {
        let text = textView.string as NSString
        guard text.length > 0 else { return nil }

        let fallbackLocation = min(textView.selectedRange().location, text.length)
        let clickLocation = charIndex >= 0 ? min(charIndex, text.length) : fallbackLocation
        let parsed = parsedDocument(for: textView.string)

        let token = parsed.imageEmbedTokens.first { token in
            token.containsSelectionOrStandaloneParagraph(clickLocation, in: text)
                || token.containsSelectionOrStandaloneParagraph(fallbackLocation, in: text)
        }

        guard let token else { return nil }
        let content = text.substring(with: token.contentRange)
        return ImageEmbedReference(content: content)
    }

    @objc private func didCopyEmbeddedImage(_ sender: NSMenuItem) {
        guard let request = sender.representedObject as? EmbeddedImageRequest,
              let image = configuration.services.images.image(for: request) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    @objc private func didCopyEmbeddedImageFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
    }

    @objc private func didRevealEmbeddedImageFile(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @objc private func didCopyEmbeddedImageMarkdown(_ sender: NSMenuItem) {
        guard let markdown = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }

    /// Returns the smallest bold or boldItalic token that fully contains the selection, or nil when the selection isn't enclosed by emphasis with a bold trait.
    func enclosingBoldToken(for selection: NSRange, in text: String) -> MarkdownToken? {
        let tokens = parsedDocument(for: text).tokens
        return tokens.first { token in
            (token.kind == .bold || token.kind == .boldItalic) && tokenEncloses(token, selection: selection)
        }
    }

    /// Returns the smallest italic or boldItalic token that fully contains the selection, or nil when the selection isn't enclosed by emphasis with an italic trait.
    func enclosingItalicToken(for selection: NSRange, in text: String) -> MarkdownToken? {
        let tokens = parsedDocument(for: text).tokens
        return tokens.first { token in
            (token.kind == .italic || token.kind == .boldItalic) && tokenEncloses(token, selection: selection)
        }
    }

    func isSelectionBold(in nsText: NSString, range: NSRange) -> Bool {
        return enclosingBoldToken(for: range, in: nsText as String) != nil
    }

    func isSelectionItalic(in nsText: NSString, range: NSRange) -> Bool {
        return enclosingItalicToken(for: range, in: nsText as String) != nil
    }

    private func tokenEncloses(_ token: MarkdownToken, selection: NSRange) -> Bool {
        return selection.location >= token.range.location
            && NSMaxRange(selection) <= NSMaxRange(token.range)
    }

    /// Replaces the marker characters of an emphasis token with `replacement` on each side, preserving the inner content.
    private func unwrapToken(_ token: MarkdownToken, leftReplacement: String, rightReplacement: String) {
        guard let tv = textView else { return }
        let nsText = tv.string as NSString
        let content = nsText.substring(with: token.contentRange)
        let newText = leftReplacement + content + rightReplacement
        if tv.shouldChangeText(in: token.range, replacementString: newText) {
            tv.replaceCharacters(in: token.range, with: newText)
            tv.didChangeText()
            let newSelectionLocation = token.range.location + leftReplacement.count
            tv.setSelectedRange(NSRange(location: newSelectionLocation, length: content.count))
            DispatchQueue.main.async { self.text = tv.string }
        }
    }

    func isSelectionHeading(level: Int, in nsText: NSString, range: NSRange) -> Bool {
        let lineRange = nsText.lineRange(for: range)
        let line = nsText.substring(with: lineRange)
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.hasPrefix(String(repeating: "#", count: level) + " ")
    }

    func isSelectionList(in nsText: NSString, range: NSRange) -> Bool {
        let lineRange = nsText.lineRange(for: range)
        let line = nsText.substring(with: lineRange)
        return line.hasPrefix("\t• ") || line.hasPrefix("1. ")
    }

    private func applyHeading(level: Int) {
        guard let tv = textView else { return }
        let nsText = tv.string as NSString
        let range = tv.selectedRange()
        let lineRange = nsText.lineRange(for: range)
        let rawLine = nsText.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)
        var content = rawLine
        while content.hasPrefix("#") { content.removeFirst() }
        content = content.trimmingCharacters(in: .whitespaces)
        let prefix = String(repeating: "#", count: level) + " "
        let newLine = prefix + content
        if tv.shouldChangeText(in: lineRange, replacementString: newLine) {
            tv.replaceCharacters(in: lineRange, with: newLine)
            tv.didChangeText()
            let newSel = NSRange(location: lineRange.location + prefix.count, length: content.count)
            tv.setSelectedRange(newSel)
            DispatchQueue.main.async { self.text = tv.string }
        }
    }

    @objc func didMarkdownHeading(_ sender: NSMenuItem) {
        applyHeading(level: sender.tag)
    }

    private func applyList(prefix: String) {
        guard let tv = textView else { return }
        let nsText = tv.string as NSString
        let selRange = tv.selectedRange()
        let startLine = nsText.lineRange(for: selRange)
        let originalLine = nsText.substring(with: startLine)
        let lineText = originalLine.trimmingCharacters(in: .newlines)
        var content = lineText
        if content.hasPrefix(prefix) {
            content = String(content.dropFirst(prefix.count))
        }
        let newLine = prefix + content
        let suffix = originalLine.hasSuffix("\n") ? "\n" : ""
        let replacement = newLine + suffix
        if tv.shouldChangeText(in: startLine, replacementString: replacement) {
            tv.replaceCharacters(in: startLine, with: replacement)
            tv.didChangeText()
            let newSel = NSRange(location: startLine.location + prefix.count, length: content.count)
            tv.setSelectedRange(newSel)
            DispatchQueue.main.async { self.text = tv.string }
        }
    }

    @objc func didMarkdownUnorderedList(_ sender: Any?) {
        applyList(prefix: "\t• ")
    }

    @objc func didMarkdownOrderedList(_ sender: Any?) {
        applyList(prefix: "1. ")
    }

    @objc func didMarkdownBold(_ sender: Any?) {
        guard let tv = textView else { return }
        let range = tv.selectedRange()

        if let token = enclosingBoldToken(for: range, in: tv.string) {
            // Toggle off: bold → plain, boldItalic → italic.
            let (left, right) = token.kind == .boldItalic ? ("*", "*") : ("", "")
            unwrapToken(token, leftReplacement: left, rightReplacement: right)
            return
        }

        if range.length == 0 {
            insertEmptyMarkers("**")
            return
        }

        wrapSelection(with: "**")
    }

    @objc func didMarkdownItalic(_ sender: Any?) {
        guard let tv = textView else { return }
        let range = tv.selectedRange()

        if let token = enclosingItalicToken(for: range, in: tv.string) {
            // Toggle off: italic → plain, boldItalic → bold.
            let (left, right) = token.kind == .boldItalic ? ("**", "**") : ("", "")
            unwrapToken(token, leftReplacement: left, rightReplacement: right)
            return
        }

        if range.length == 0 {
            insertEmptyMarkers("*")
            return
        }

        wrapSelection(with: "*")
    }

    @objc func didMarkdownStrikethrough(_ sender: Any?) {
        toggleDelimitedSelection(with: "~~")
    }

    @objc func didMarkdownInlineCode(_ sender: Any?) {
        toggleDelimitedSelection(with: "`")
    }

    @objc func didMarkdownLink(_ sender: Any?) {
        guard let tv = textView else { return }
        let selection = tv.selectedRange()
        let source = tv.string as NSString
        let prefixLocation = selection.location - 1
        let suffixLocation = NSMaxRange(selection)
        if prefixLocation >= 0,
           source.substring(with: NSRange(location: prefixLocation, length: 1)) == "[",
           suffixLocation + 2 <= source.length,
           source.substring(with: NSRange(location: suffixLocation, length: 2)) == "](" {
            let closing = source.range(
                of: ")",
                options: [],
                range: NSRange(
                    location: suffixLocation + 2,
                    length: source.length - suffixLocation - 2
                )
            )
            if closing.location != NSNotFound {
                let replacementRange = NSRange(
                    location: prefixLocation,
                    length: NSMaxRange(closing) - prefixLocation
                )
                let selectedText = source.substring(with: selection)
                replaceMarkdown(
                    in: tv,
                    range: replacementRange,
                    with: selectedText,
                    selection: NSRange(location: prefixLocation, length: selection.length)
                )
                return
            }
        }

        let destination = "https://"
        let selectedText = source.substring(with: selection)
        let replacement = "[\(selectedText)](\(destination))"
        replaceMarkdown(
            in: tv,
            range: selection,
            with: replacement,
            selection: NSRange(
                location: selection.location + selection.length + 3,
                length: (destination as NSString).length
            )
        )
    }

    private func toggleDelimitedSelection(with marker: String) {
        guard let tv = textView else { return }
        let source = tv.string as NSString
        let selection = tv.selectedRange()
        let markerLength = (marker as NSString).length
        let prefixRange = NSRange(
            location: selection.location - markerLength,
            length: markerLength
        )
        let suffixRange = NSRange(location: NSMaxRange(selection), length: markerLength)
        let isWrapped = prefixRange.location >= 0
            && NSMaxRange(suffixRange) <= source.length
            && source.substring(with: prefixRange) == marker
            && source.substring(with: suffixRange) == marker

        if isWrapped {
            let replacementRange = NSRange(
                location: prefixRange.location,
                length: markerLength + selection.length + markerLength
            )
            replaceMarkdown(
                in: tv,
                range: replacementRange,
                with: source.substring(with: selection),
                selection: NSRange(location: prefixRange.location, length: selection.length)
            )
            return
        }

        let selectedText = source.substring(with: selection)
        replaceMarkdown(
            in: tv,
            range: selection,
            with: marker + selectedText + marker,
            selection: NSRange(
                location: selection.location + markerLength,
                length: selection.length
            )
        )
    }

    private func replaceMarkdown(
        in textView: NSTextView,
        range: NSRange,
        with replacement: String,
        selection: NSRange
    ) {
        guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
        textView.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        textView.setSelectedRange(selection)
        DispatchQueue.main.async { self.text = textView.string }
    }

    private func insertEmptyMarkers(_ marker: String) {
        guard let tv = textView else { return }
        let range = tv.selectedRange()
        let insertion = marker + marker
        if tv.shouldChangeText(in: range, replacementString: insertion) {
            tv.replaceCharacters(in: range, with: insertion)
            tv.didChangeText()
            tv.setSelectedRange(NSRange(location: range.location + marker.count, length: 0))
            DispatchQueue.main.async { self.text = tv.string }
        }
    }

    private func wrapSelection(with marker: String) {
        guard let tv = textView else { return }
        let nsText = tv.string as NSString
        let range = tv.selectedRange()
        let original = nsText.substring(with: range)
        let leadingWS = original.prefix { $0.isWhitespace }.count
        let trailingWS = original.reversed().prefix { $0.isWhitespace }.count
        let coreStart = original.index(original.startIndex, offsetBy: leadingWS)
        let coreEnd = original.index(original.endIndex, offsetBy: -trailingWS)
        let core = coreStart <= coreEnd ? String(original[coreStart..<coreEnd]) : ""
        let leading = String(original[..<coreStart])
        let trailing = String(original[coreEnd...])
        let newText = leading + marker + core + marker + trailing
        if tv.shouldChangeText(in: range, replacementString: newText) {
            tv.replaceCharacters(in: range, with: newText)
            tv.didChangeText()
            let newRange = NSRange(location: range.location + leadingWS + marker.count, length: core.count)
            tv.setSelectedRange(newRange)
            DispatchQueue.main.async { self.text = tv.string }
        }
    }
}

// MARK: - Menu Item Validation
extension NativeTextViewWrapper.Coordinator: NSMenuItemValidation {
    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let tv = textView else { return true }
        let nsText = tv.string as NSString
        let range = tv.selectedRange()
        switch menuItem.action {
        case #selector(didMarkdownBold(_:)):
            menuItem.state = enclosingBoldToken(for: range, in: tv.string) != nil ? .on : .off
            return true
        case #selector(didMarkdownItalic(_:)):
            menuItem.state = enclosingItalicToken(for: range, in: tv.string) != nil ? .on : .off
            return true
        case #selector(didMarkdownHeading(_:)):
            return !isSelectionHeading(level: menuItem.tag, in: nsText, range: range)
        case #selector(didMarkdownUnorderedList(_:)),
             #selector(didMarkdownOrderedList(_:)):
            return !isSelectionList(in: nsText, range: range)
        case #selector(didCopyEmbeddedImage(_:)):
            return menuItem.representedObject is EmbeddedImageRequest
        case #selector(didCopyEmbeddedImageFile(_:)),
             #selector(didRevealEmbeddedImageFile(_:)):
            return menuItem.representedObject is URL
        case #selector(didCopyEmbeddedImageMarkdown(_:)):
            return menuItem.representedObject is String
        default:
            return true
        }
    }
}
