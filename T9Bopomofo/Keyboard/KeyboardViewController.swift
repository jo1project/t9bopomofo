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

    private let collapsedHeight: CGFloat = 268
    private let expandedHeight: CGFloat = 360

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.82, alpha: 1)
        engine.prepare(bundle: Bundle(for: KeyboardViewController.self))

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        engine.prepare(bundle: Bundle(for: KeyboardViewController.self))
        AppSettings.shared.reloadFromDisk()
        if !engine.isComposing {
            refreshPredictionsFromDocument()
        }
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
        keyboardContainer.subviews.forEach { $0.removeFromSuperview() }
        switch mode {
        case .zhuyin:
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
        case .english:
            let en = EnglishKeyboardView()
            en.translatesAutoresizingMaskIntoConstraints = false
            keyboardContainer.addSubview(en)
            pin(en)
            en.onInsert = { [weak self] s in
                guard let self else { return }
                _ = self.engine.insertPassthroughAndClear("")
                self.textDocumentProxy.insertText(s)
                self.reloadCandidates()
            }
            en.onBackspace = { [weak self] in self?.textDocumentProxy.deleteBackward() }
            en.onMode = { [weak self] m in
                self?.mode = m
                self?.renderKeyboard()
            }
        case .symbols:
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
        case .emoji:
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
            // Soft tone: omit tone marker (Rime treats missing tone as 輕聲).
            break
        case .exact(let token, _):
            engine.tapExactToken(token)
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
        case .space:
            let out = engine.handleSpace()
            textDocumentProxy.insertText(out)
        case .enter:
            let out = engine.handleReturn()
            textDocumentProxy.insertText(out)
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
        reloadCandidates()
    }
}
