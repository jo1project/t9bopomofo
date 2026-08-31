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
    private weak var punctuationTray: PunctuationTrayView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.82, alpha: 1)
        engine.prepare(bundle: Bundle(for: KeyboardViewController.self))

        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(candidateBar)
        view.addSubview(keyboardContainer)

        NSLayoutConstraint.activate([
            candidateBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            candidateBar.heightAnchor.constraint(equalToConstant: 36),

            keyboardContainer.topAnchor.constraint(equalTo: candidateBar.bottomAnchor, constant: 4),
            keyboardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            keyboardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            keyboardContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -3),
        ])

        let hc = view.heightAnchor.constraint(equalToConstant: 308)
        hc.priority = .required
        hc.isActive = true
        heightConstraint = hc

        // Candidate bar slightly tighter so 4 key rows get Hamster-like height
        // (constraints already set above)

        candidateBar.onSelect = { [weak self] candidate in
            guard let self else { return }
            let text = self.engine.selectCandidate(candidate)
            self.textDocumentProxy.insertText(text)
            self.reloadCandidates()
        }

        NotificationCenter.default.addObserver(
            forName: .t9SwitchEmoji,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.mode = .emoji
            self?.renderKeyboard()
        }

        renderKeyboard()
        reloadCandidates()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        engine.prepare(bundle: Bundle(for: KeyboardViewController.self))
    }

    private func reloadCandidates() {
        candidateBar.setCandidates(engine.candidates, preedit: engine.preeditDisplay)
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
                self?.renderKeyboard()
            }
        case .english:
            let en = EnglishKeyboardView()
            en.translatesAutoresizingMaskIntoConstraints = false
            keyboardContainer.addSubview(en)
            pin(en)
            en.onInsert = { [weak self] s in
                guard let self else { return }
                // Passthrough clears composing per product rule when switching contexts
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
            hidePunctuationTray()
            engine.tapT9Key(ch)
        case .tone(let ch):
            hidePunctuationTray()
            engine.tapTone(ch)
        case .exact(let token, _):
            hidePunctuationTray()
            engine.tapExactToken(token)
        case .backspace:
            if punctuationTray != nil {
                hidePunctuationTray()
                return
            }
            if !engine.isComposing {
                textDocumentProxy.deleteBackward()
            } else {
                engine.backspace()
            }
        case .numberPad:
            hidePunctuationTray()
            mode = .symbols
            renderKeyboard()
            return
        case .punctuationMenu:
            if punctuationTray != nil {
                hidePunctuationTray()
            } else {
                showPunctuationTray()
            }
            return
        case .symbol(let s):
            hidePunctuationTray()
            let out = engine.handleSymbol(s)
            textDocumentProxy.insertText(out)
        case .space:
            hidePunctuationTray()
            let out = engine.handleSpace()
            textDocumentProxy.insertText(out)
        case .enter:
            hidePunctuationTray()
            let out = engine.handleReturn()
            textDocumentProxy.insertText(out)
        }
        reloadCandidates()
    }

    private func showPunctuationTray() {
        hidePunctuationTray()
        let tray = PunctuationTrayView()
        tray.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tray)
        NSLayoutConstraint.activate([
            tray.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            tray.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            tray.bottomAnchor.constraint(equalTo: keyboardContainer.topAnchor, constant: -2),
            tray.heightAnchor.constraint(equalToConstant: 52),
        ])
        tray.onPick = { [weak self] symbol in
            guard let self else { return }
            let out = self.engine.handleSymbol(symbol)
            self.textDocumentProxy.insertText(out)
            self.hidePunctuationTray()
            self.reloadCandidates()
        }
        tray.onDismiss = { [weak self] in
            self?.hidePunctuationTray()
        }
        punctuationTray = tray
        // Grow keyboard a bit so tray doesn't crush candidates
        heightConstraint?.constant = 360
    }

    private func hidePunctuationTray() {
        punctuationTray?.removeFromSuperview()
        punctuationTray = nil
        heightConstraint?.constant = 308
    }
}
