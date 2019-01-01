import UIKit
import Foundation

final internal class VTextStorage: NSTextStorage, NSTextStorageDelegate {
    
    enum TypingStatus {
        
        case typing // Insert new single character as keyboard
        case remove // Remove character as keyboard
        case install // Directly set attributedString at storage
        case none // unknown or default status
    }
    
    internal var status: TypingStatus = .none
    internal var typingManager: VTextManager?
    
    private var internalAttributedString: NSMutableAttributedString = NSMutableAttributedString()
    private var prevLocation: Int = 0
    
    override var string: String {
        return self.internalAttributedString.string
    }
    
    internal var currentTypingAttribute: [NSAttributedString.Key: Any] = [:]
    
    convenience init(typingManager: VTextManager) {
        self.init()
        self.typingManager = typingManager
        self.delegate = self
    }
    
    override init() {
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func attributes(at location: Int,
                             effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        guard self.internalAttributedString.length > location else { return [:] }
        return internalAttributedString.attributes(at: location, effectiveRange: range)
    }
    
    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        guard internalAttributedString.length > range.location else { return }
        
        switch status {
        case .typing, .install:
            break
        default:
            return
        }
        
        self.beginEditing()
        self.internalAttributedString.setAttributes(attrs, range: range)
        self.edited(.editedAttributes, range: range, changeInLength: 0)
        self.endEditing()
    }
    
    public func replaceAttributesIfNeeds(_ textView: UITextView) {
        guard textView.selectedRange.length > 1 else { return }
        self.status = .install
        self.setAttributes(self.currentTypingAttribute,
                           range: textView.selectedRange)
    }
    
    override func processEditing() {
        switch status {
        case .typing:
            self.internalAttributedString.setAttributes(self.currentTypingAttribute,
                                                        range: self.editedRange)
        default:
            break
        }
        
        super.processEditing()
    }
    
    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorage.EditActions,
                     range editedRange: NSRange,
                     changeInLength delta: Int) {
        self.status = .none
    }
    
    override func setAttributedString(_ attrString: NSAttributedString) {
        self.status = .install
        super.setAttributedString(attrString)
    }
    
    override func replaceCharacters(in range: NSRange, with str: String) {
        if self.status != .install {
            self.status = str.isEmpty ? .remove: .typing
        }
        
        self.beginEditing()
        self.internalAttributedString.replaceCharacters(in: range, with: str)
        self.edited(.editedCharacters,
                    range: range,
                    changeInLength: str.count - range.length)
        self.endEditing()
    }
    
    internal func updateCurrentLocationAttributesIfNeeds(_ textView: VTextView) {
        
        if textView.selectedRange.length < 1,
            abs(textView.selectedRange.location - self.prevLocation) > 1 {
            
            let currentAttributes =
                self.attributes(at: max(0, textView.selectedRange.location - 1),
                                effectiveRange: nil)
            
            if let keys = currentAttributes[VTextManager.managerKey] as? [String]  {
                textView.currentTypingAttribute = currentAttributes
                self.typingManager?.fetchActiveAttribute(keys)
            } else {
                let key = typingManager?.defaultKey ?? ""
                let defaultAttributes = typingManager?.defaultAttribute ?? [:]
                textView.currentTypingAttribute = defaultAttributes
                self.typingManager?.resetStatus()
                self.typingManager?.updateCurrentAttribute(key)
            }
        }
        
        self.prevLocation = textView.selectedRange.location
    }
    
    public func paragraphStyleRange(_ textView: VTextView) -> NSRange {
        return NSString(string: self.internalAttributedString.string)
            .paragraphRange(for: textView.selectedRange)
    }
}

extension VTextStorage {
    
    internal func parseToXML(packageTag: String?) -> String {
        guard let manager = typingManager else { return "" }
        return VTextXMLBuilder.shared.parseToXML(typingManager: manager,
                                                 internalAttributedString: internalAttributedString,
                                                 packageTag: packageTag)
    }
    
    internal func xmlToStorage(_ string: String) {
        guard let manager = self.typingManager else { return }
        _ = VTextXMLParser(string, manager: manager, complateHandler: { attr in
            self.setAttributedString(attr)
        })
    }
}
