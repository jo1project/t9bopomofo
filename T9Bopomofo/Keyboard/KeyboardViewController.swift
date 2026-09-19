import UIKit

enum KeyboardMode: String, CaseIterable {
    case zhuyin
    case english
    case symbols
    case emoji
}

final class KeyboardViewController: UIInputViewController {
    private let engine = InputEngine()
    private var mode: KeyboardMode = .zhuyin

    private let candidateBar = CandidateBarView()
    private let keyboardContainer = UIView()
    private var heightConstraint: NSLayoutConstraint?
    private var candidateBarHeight: NSLayoutConstraint?
    private weak var candidatePanel: CandidatePanelView?
    private var candidatesExpanded = false

    // Cached keyboard views for reuse
    private var zhuyinKeyboard: ZhuyinKeyboardView?
    private var englishKeyboard: EnglishKeyboardView?
    private var symbolKeyboard: SymbolKeyboardView?
    private var emojiKeyboard: EmojiKeyboardView?

    private let collapsedHeight: CGFloat = 268
    private let expandedHeight: CGFloat = 360

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = KeyboardChrome.background(for: traitCollection)

        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(candidateBar)
        view.addSubview(keyboardContainer)

        let barH = candidateBar.heightAnchor.constraint(equalToConstant: 40)
        candidateBarHeight = barH

        NSLayoutConstraint.activate([
            candidateBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            barH,

            keyboardContainer.topAnchor.constraint(equalTo: candidateBar.bottomAnchor, constant: 2),
            keyboardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            keyboardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            keyboardContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),
        ])

        let hc = view.heightAnchor.constraint(equalToConstant: collapsedHeight)
        hc.priority = .required
        hc.isActive = true
        heightConstraint = hc

        candidateBar.onSelect = { [weak self] candidate in
            guard let self else { return }
            if self.mode == .english {
                self.acceptEnglishSuggestion(candidate)
                return
            }
            let text = self.engine.selectCandidate(candidate)
            self.textDocumentProxy.insertText(text)
            self.collapseCandidates()
            self.refreshPredictionsAfterCommit(inserted: text)
        }
        candidateBar.onToggleExpand = { [weak self] in
            self?.toggleCandidatesExpanded()
        }
        candidateBar.onDismissKeyboard = { [weak self] in
            self?.dismissKeyboard()
        }

        engine.onCandidatesChanged = { [weak self] in
            self?.reloadCandidates()
        }

        NotificationCenter.default.addObserver(
            forName: .t9SwitchEmoji,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.mode = .emoji
            self?.collapseCandidates()
            self?.renderKeyboard()
        }

        renderKeyboard()
        reloadCandidates()

        engine.prepare(bundle: Bundle(for: KeyboardViewController.self))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.backgroundColor = KeyboardChrome.background(for: traitCollection)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppSettings.shared.reloadFromDisk()
        if mode == .english {
            refreshEnglishSuggestions()
        } else if !engine.isComposing {
            refreshPredictionsFromDocument()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        engine.flushUserLexicon()
    }

    // MARK: - English spelling suggestions (UITextChecker, opt-in via candidate bar tap)

    private static let textChecker = UITextChecker()

    private static func trailingWord(in text: String) -> String {
        String(text.reversed().prefix { $0.isLetter && $0.isASCII }.reversed())
    }

    private func refreshEnglishSuggestions() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let word = Self.trailingWord(in: before)
        guard word.count >= 2 else {
            candidateBar.setCandidates([], preedit: "")
            return
        }
        let range = NSRange(location: 0, length: word.utf16.count)
        guard Self.textChecker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: "en_US").location != NSNotFound else {
            candidateBar.setCandidates([], preedit: "")
            return
        }
        let guesses = Self.textChecker.guesses(forWordRange: range, in: word, language: "en_US") ?? []
        let candidates = guesses.prefix(5).enumerated().map { idx, g in
            Candidate(id: "spell-\(idx)-\(g)", text: g, reading: "", score: Double(100 - idx), source: .prediction)
        }
        candidateBar.setCandidates(candidates, preedit: "")
    }

    private func acceptEnglishSuggestion(_ candidate: Candidate) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let word = Self.trailingWord(in: before)
        guard !word.isEmpty else { return }
        for _ in 0..<word.count {
            textDocumentProxy.deleteBackward()
        }
        var replacement = candidate.text
        if let first = word.first, first.isUppercase {
            replacement = replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        textDocumentProxy.insertText(replacement + " ")
        candidateBar.setCandidates([], preedit: "")
    }

    private func reloadCandidates() {
        candidateBar.setCandidates(
            engine.candidates,
            preedit: engine.preeditDisplay,
            status: engine.isComposing ? "" : engine.predictionStatus
        )
        candidatePanel?.setCandidates(engine.candidates)
    }

    /// After committing text, ask LLM using document tail (not only the last word).
    private func refreshPredictionsAfterCommit(inserted: String) {
        reloadCandidates()
        guard !inserted.isEmpty else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let context = before.isEmpty ? inserted : before
        engine.requestNextWordPredictions(context: context, hasNetworkAccess: hasFullAccess)
        reloadCandidates()
    }

    private func refreshPredictionsFromDocument() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let tail = before.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tail.isEmpty else {
            reloadCandidates()
            return
        }
        // Only auto-trigger when the tail looks like CJK (avoid English spam).
        let hasCJK = tail.unicodeScalars.contains { s in
            (0x4E00...0x9FFF).contains(s.value) || (0x3400...0x4DBF).contains(s.value)
        }
        guard hasCJK else {
            reloadCandidates()
            return
        }
        engine.requestNextWordPredictions(context: tail, hasNetworkAccess: hasFullAccess)
        reloadCandidates()
    }

    private func toggleCandidatesExpanded() {
        if candidatesExpanded {
            collapseCandidates()
        } else {
            expandCandidates()
        }
    }

    private func expandCandidates() {
        candidatesExpanded = true
        candidateBar.setExpanded(true)
        engine.setCandidateLimit(64)
        reloadCandidates()

        candidatePanel?.removeFromSuperview()
        let panel = CandidatePanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: candidateBar.bottomAnchor, constant: 2),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])
        panel.onSelect = { [weak self] candidate in
            guard let self else { return }
            let text = self.engine.selectCandidate(candidate)
            self.textDocumentProxy.insertText(text)
            self.collapseCandidates()
            self.refreshPredictionsAfterCommit(inserted: text)
        }
        panel.setCandidates(engine.candidates)
        candidatePanel = panel
        keyboardContainer.isHidden = true
        heightConstraint?.constant = expandedHeight
    }

    private func collapseCandidates() {
        candidatesExpanded = false
        candidateBar.setExpanded(false)
        engine.setCandidateLimit(12)
        candidatePanel?.removeFromSuperview()
        candidatePanel = nil
        keyboardContainer.isHidden = false
        heightConstraint?.constant = collapsedHeight
        reloadCandidates()
    }

    private func renderKeyboard() {
        // Hide all cached keyboards first
        zhuyinKeyboard?.isHidden = true
        englishKeyboard?.isHidden = true
        symbolKeyboard?.isHidden = true
        emojiKeyboard?.isHidden = true

        switch mode {
        case .zhuyin:
            if zhuyinKeyboard == nil {
                let grid = ZhuyinKeyboardView()
                grid.translatesAutoresizingMaskIntoConstraints = false
                keyboardContainer.addSubview(grid)
                NSLayoutConstraint.activate([
                    grid.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
                    grid.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
                    grid.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
                    grid.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor),
                ])
                grid.onAction = { [weak self] action in
                    self?.handleZhuyin(action)
                }
                grid.onMode = { [weak self] in
                    self?.mode = .english
                    self?.collapseCandidates()
                    self?.renderKeyboard()
                }
                zhuyinKeyboard = grid
            }
            zhuyinKeyboard?.isHidden = false
        case .english:
            if englishKeyboard == nil {
                let en = EnglishKeyboardView()
                en.translatesAutoresizingMaskIntoConstraints = false
                keyboardContainer.addSubview(en)
                pin(en)
                en.onInsert = { [weak self] s in
                    guard let self else { return }
                    self.textDocumentProxy.insertText(s)
                    // ponytail: skip engine/reload in EN mode - direct insert faster
                    self.refreshEnglishSuggestions()
                }
                en.onBackspace = { [weak self] in
                    guard let self else { return }
                    self.textDocumentProxy.deleteBackward()
                    self.refreshEnglishSuggestions()
                }
                en.onMode = { [weak self] m in
                    self?.candidateBar.setCandidates([], preedit: "")
                    self?.mode = m
                    self?.renderKeyboard()
                }
                englishKeyboard = en
            }
            englishKeyboard?.isHidden = false
            refreshEnglishSuggestions()
        case .symbols:
            if symbolKeyboard == nil {
                let sym = SymbolKeyboardView()
                sym.translatesAutoresizingMaskIntoConstraints = false
                keyboardContainer.addSubview(sym)
                pin(sym)
                sym.onInsert = { [weak self] s in
                    guard let self else { return }
                    let out = self.engine.handleSymbol(s)
                    self.textDocumentProxy.insertText(out)
                    self.reloadCandidates()
                }
                sym.onBackspace = { [weak self] in self?.textDocumentProxy.deleteBackward() }
                sym.onMode = { [weak self] m in
                    self?.mode = m
                    self?.renderKeyboard()
                }
                symbolKeyboard = sym
            }
            symbolKeyboard?.isHidden = false
        case .emoji:
            if emojiKeyboard == nil {
                let em = EmojiKeyboardView()
                em.translatesAutoresizingMaskIntoConstraints = false
                keyboardContainer.addSubview(em)
                pin(em)
                em.onInsert = { [weak self] s in
                    guard let self else { return }
                    _ = self.engine.insertPassthroughAndClear("")
                    self.textDocumentProxy.insertText(s)
                    self.reloadCandidates()
                }
                em.onMode = { [weak self] m in
                    self?.mode = m
                    self?.renderKeyboard()
                }
                emojiKeyboard = em
            }
            emojiKeyboard?.isHidden = false
        }
    }

    private func pin(_ child: UIView) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
            child.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
            child.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor),
        ])
    }

    private func handleZhuyin(_ action: ZhuyinPhoneLayout.KeyAction) {
        switch action {
        case .t9(let ch):
            engine.tapT9Key(ch)
        case .tone(let ch):
            engine.tapTone(ch)
        case .toneNeutral:
            engine.tapTone("˙")
        case .exact(let token, let label):
            engine.tapExactToken(token, zhuyin: label.first ?? token)
        case .backspace:
            if !engine.isComposing {
                textDocumentProxy.deleteBackward()
            } else {
                engine.backspace()
            }
        case .numberPad:
            mode = .symbols
            collapseCandidates()
            renderKeyboard()
            return
        case .symbol(let s):
            let out = engine.handleSymbol(s)
            textDocumentProxy.insertText(out)
            reloadCandidates()
        case .space:
            // ponytail: space = tone1 when composing, else space
            if engine.isComposing {
                engine.tapTone("q")
            } else {
                let out = engine.handleSpace()
                textDocumentProxy.insertText(out)
                reloadCandidates()
            }
        case .enter:
            let out = engine.handleReturn()
            textDocumentProxy.insertText(out)
            reloadCandidates()
        case .switchEnglish:
            mode = .english
            collapseCandidates()
            renderKeyboard()
            return
        case .switchEmoji:
            mode = .emoji
            collapseCandidates()
            renderKeyboard()
            return
        }
        if candidatesExpanded {
            engine.setCandidateLimit(64)
        }
        // ponytail: update space key label dynamically
        zhuyinKeyboard?.updateSpaceKey(isComposing: engine.isComposing)
        // The engine's onCandidatesChanged already reloaded for every path that changes candidates
        // (t9/tone/exact/backspace/space-while-composing); symbol/space/enter reload above.
    }
}
