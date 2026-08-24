#if canImport(UIKit)
import UIKit
import CoreImage

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ScoutViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

private final class ScoutViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let qrImageView = UIImageView()
    private let payloadTextView = UITextView()

    private let scoutField = UITextField.scoutField(placeholder: "Scout name")
    private let matchField = UITextField.scoutField(placeholder: "Match")
    private let teamField = UITextField.scoutField(placeholder: "Team")
    private let robotField = UITextField.scoutField(placeholder: "Robot notes")
    private let commentsView = UITextView.scoutNotes()

    private let allianceControl = UISegmentedControl(items: ["Red", "Blue"])
    private let stationControl = UISegmentedControl(items: ["1", "2", "3"])
    private let endgameControl = UISegmentedControl(items: ["None", "Park", "Climb", "Fail"])

    private let autoMobility = CounterControl(title: "Auto Mobility")
    private let autoFuel = CounterControl(title: "Auto Fuel")
    private let autoAmp = CounterControl(title: "Auto Amp")
    private let teleopSpeaker = CounterControl(title: "Teleop Speaker")
    private let teleopAmp = CounterControl(title: "Teleop Amp")
    private let teleopFeed = CounterControl(title: "Fed Pieces")
    private let fouls = CounterControl(title: "Fouls")
    private let defense = CounterControl(title: "Defense Rating")

    private var counterControls: [CounterControl] {
        [autoMobility, autoFuel, autoAmp, teleopSpeaker, teleopAmp, teleopFeed, fouls, defense]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "QRScout MECO"
        view.backgroundColor = UIColor(white: 0.96, alpha: 1.0)
        configureNavigation()
        configureLayout()
        generateQRCode()
    }

    private func configureNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Commit",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(commitTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Reset",
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(resetTapped))
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomLayoutGuide.topAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        [scoutField, matchField, teamField, robotField].forEach { field in
            field.delegate = self
            field.addTarget(self, action: #selector(formChanged), for: .editingChanged)
        }
        matchField.keyboardType = .numberPad
        teamField.keyboardType = .numberPad
        commentsView.delegate = self

        allianceControl.selectedSegmentIndex = 0
        stationControl.selectedSegmentIndex = 0
        endgameControl.selectedSegmentIndex = 0
        [allianceControl, stationControl, endgameControl].forEach { control in
            control.addTarget(self, action: #selector(formChanged), for: .valueChanged)
        }

        counterControls.forEach { control in
            control.valueChanged = { [weak self] in self?.generateQRCode() }
        }
        defense.maximumValue = 5

        contentStack.addArrangedSubview(section(title: "Prematch", views: [
            row([scoutField, matchField, teamField]),
            labeledControl(title: "Alliance", control: allianceControl),
            labeledControl(title: "Station", control: stationControl),
            robotField
        ]))

        contentStack.addArrangedSubview(section(title: "Autonomous", views: [
            autoMobility,
            autoFuel,
            autoAmp
        ]))

        contentStack.addArrangedSubview(section(title: "Teleop", views: [
            teleopSpeaker,
            teleopAmp,
            teleopFeed,
            fouls,
            defense
        ]))

        contentStack.addArrangedSubview(section(title: "Endgame & Notes", views: [
            labeledControl(title: "Endgame", control: endgameControl),
            commentsView
        ]))

        configureOutputSection()
    }

    private func configureOutputSection() {
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.backgroundColor = .white
        qrImageView.layer.borderColor = UIColor(white: 0.85, alpha: 1.0).cgColor
        qrImageView.layer.borderWidth = 1
        qrImageView.heightAnchor.constraint(equalToConstant: 240).isActive = true

        payloadTextView.isEditable = false
        payloadTextView.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: UIFont.Weight.regular)
        payloadTextView.layer.cornerRadius = 6
        payloadTextView.layer.borderColor = UIColor(white: 0.82, alpha: 1.0).cgColor
        payloadTextView.layer.borderWidth = 1
        payloadTextView.heightAnchor.constraint(equalToConstant: 86).isActive = true

        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy Payload", for: .normal)
        copyButton.addTarget(self, action: #selector(copyPayloadTapped), for: .touchUpInside)

        let columnsButton = UIButton(type: .system)
        columnsButton.setTitle("Copy Column Names", for: .normal)
        columnsButton.addTarget(self, action: #selector(copyColumnsTapped), for: .touchUpInside)

        contentStack.addArrangedSubview(section(title: "QR Output", views: [
            qrImageView,
            payloadTextView,
            row([copyButton, columnsButton])
        ]))
    }

    private func section(title: String, views: [UIView]) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 10
        container.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        container.isLayoutMarginsRelativeArrangement = true
        container.backgroundColor = .white
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(white: 0.86, alpha: 1.0).cgColor

        let label = UILabel()
        label.text = title
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = UIColor(white: 0.12, alpha: 1.0)
        container.addArrangedSubview(label)
        views.forEach { container.addArrangedSubview($0) }
        return container
    }

    private func row(_ views: [UIView]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .horizontal
        stack.spacing = 10
        stack.distribution = .fillEqually
        return stack
    }

    private func labeledControl(title: String, control: UISegmentedControl) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 15, weight: UIFont.Weight.semibold)

        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .vertical
        stack.spacing = 6
        return stack
    }

    @objc private func commitTapped() {
        view.endEditing(true)
        generateQRCode()
        showMessage(title: "QR Code Ready", message: "The scouting payload has been encoded.")
    }

    @objc private func resetTapped() {
        matchField.text = nextMatchValue()
        teamField.text = ""
        robotField.text = ""
        commentsView.text = ""
        stationControl.selectedSegmentIndex = 0
        endgameControl.selectedSegmentIndex = 0
        counterControls.forEach { $0.reset() }
        generateQRCode()
    }

    @objc private func copyPayloadTapped() {
        UIPasteboard.general.string = payloadTextView.text
        showMessage(title: "Copied", message: "Payload copied to the clipboard.")
    }

    @objc private func copyColumnsTapped() {
        UIPasteboard.general.string = columns().joined(separator: ",")
        showMessage(title: "Copied", message: "Column names copied to the clipboard.")
    }

    @objc private func formChanged() {
        generateQRCode()
    }

    func textViewDidChange(_ textView: UITextView) {
        generateQRCode()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func generateQRCode() {
        let payload = values().joined(separator: ",")
        payloadTextView.text = payload
        qrImageView.image = makeQRCode(from: payload)
    }

    private func columns() -> [String] {
        [
            "scout", "match", "team", "alliance", "station", "robotNotes",
            "autoMobility", "autoFuel", "autoAmp", "teleopSpeaker", "teleopAmp",
            "teleopFeed", "fouls", "defenseRating", "endgame", "comments"
        ]
    }

    private func values() -> [String] {
        [
            clean(scoutField.text),
            clean(matchField.text),
            clean(teamField.text),
            selectedTitle(allianceControl),
            selectedTitle(stationControl),
            clean(robotField.text),
            String(autoMobility.value),
            String(autoFuel.value),
            String(autoAmp.value),
            String(teleopSpeaker.value),
            String(teleopAmp.value),
            String(teleopFeed.value),
            String(fouls.value),
            String(defense.value),
            selectedTitle(endgameControl),
            clean(commentsView.text)
        ]
    }

    private func selectedTitle(_ control: UISegmentedControl) -> String {
        let index = control.selectedSegmentIndex
        guard index >= 0 else { return "" }
        return control.titleForSegment(at: index) ?? ""
    }

    private func clean(_ text: String?) -> String {
        guard let text = text else { return "" }
        return text
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nextMatchValue() -> String {
        guard let current = matchField.text, let match = Int(current) else { return "" }
        return String(match + 1)
    }

    private func makeQRCode(from text: String) -> UIImage? {
        guard let data = text.data(using: String.Encoding.isoLatin1),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let output = filter.outputImage else { return nil }
        let scale = UIScreen.main.scale * 8
        let scaledImage = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return UIImage(ciImage: scaledImage)
    }

    private func showMessage(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

private final class CounterControl: UIStackView {
    var valueChanged: (() -> Void)?
    var minimumValue = 0
    var maximumValue = 99
    private(set) var value = 0 {
        didSet { valueLabel.text = String(value) }
    }

    private let valueLabel = UILabel()

    init(title: String) {
        super.init(frame: CGRect.zero)
        axis = .horizontal
        spacing = 10
        alignment = .center
        distribution = .fill

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.semibold)
        titleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        let minusButton = UIButton(type: .system)
        minusButton.setTitle("-", for: .normal)
        minusButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 26)
        minusButton.addTarget(self, action: #selector(decrement), for: .touchUpInside)

        let plusButton = UIButton(type: .system)
        plusButton.setTitle("+", for: .normal)
        plusButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        plusButton.addTarget(self, action: #selector(increment), for: .touchUpInside)

        valueLabel.text = "0"
        valueLabel.textAlignment = .center
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: UIFont.Weight.semibold)
        valueLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        [minusButton, plusButton].forEach { button in
            button.layer.borderColor = UIColor(white: 0.78, alpha: 1.0).cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 6
            button.widthAnchor.constraint(equalToConstant: 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        }

        addArrangedSubview(titleLabel)
        addArrangedSubview(minusButton)
        addArrangedSubview(valueLabel)
        addArrangedSubview(plusButton)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reset() {
        value = minimumValue
        valueChanged?()
    }

    @objc private func increment() {
        value = min(maximumValue, value + 1)
        valueChanged?()
    }

    @objc private func decrement() {
        value = max(minimumValue, value - 1)
        valueChanged?()
    }
}

private extension UITextField {
    static func scoutField(placeholder: String) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.borderStyle = .roundedRect
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .done
        field.autocorrectionType = .no
        field.autocapitalizationType = .words
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return field
    }
}

private extension UITextView {
    static func scoutNotes() -> UITextView {
        let view = UITextView()
        view.font = UIFont.systemFont(ofSize: 16)
        view.layer.cornerRadius = 6
        view.layer.borderColor = UIColor(white: 0.78, alpha: 1.0).cgColor
        view.layer.borderWidth = 1
        view.heightAnchor.constraint(equalToConstant: 110).isActive = true
        return view
    }
}

#else
import SwiftUI
import CoreImage
import Playgrounds

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var scoutName = ""
    @State private var matchNumber = ""
    @State private var teamNumber = ""
    @State private var robotNotes = ""
    @State private var alliance = "Red"
    @State private var station = "1"
    @State private var endgame = "None"
    @State private var comments = ""

    @State private var autoMobility = 0
    @State private var autoFuel = 0
    @State private var autoAmp = 0
    @State private var teleopSpeaker = 0
    @State private var teleopAmp = 0
    @State private var teleopFeed = 0
    @State private var fouls = 0
    @State private var defenseRating = 0
    @State private var showCommitConfirmation = false

    private let alliances = ["Red", "Blue"]
    private let stations = ["1", "2", "3"]
    private let endgameOptions = ["None", "Park", "Climb", "Fail"]

    private var columnNames: [String] {
        [
            "scout", "match", "team", "alliance", "station", "robotNotes",
            "autoMobility", "autoFuel", "autoAmp", "teleopSpeaker", "teleopAmp",
            "teleopFeed", "fouls", "defenseRating", "endgame", "comments"
        ]
    }

    private var payloadValues: [String] {
        [
            clean(scoutName), clean(matchNumber), clean(teamNumber), alliance, station,
            clean(robotNotes), String(autoMobility), String(autoFuel), String(autoAmp),
            String(teleopSpeaker), String(teleopAmp), String(teleopFeed), String(fouls),
            String(defenseRating), endgame, clean(comments)
        ]
    }

    private var payload: String {
        payloadValues.joined(separator: ",")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                prematchSection
                autonomousSection
                teleopSection
                endgameSection
                outputSection
            }
            .padding(16)
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
        .alert(isPresented: $showCommitConfirmation) {
            Alert(title: Text("QR Code Ready"), message: Text("The scouting payload has been encoded."), dismissButton: .default(Text("OK")))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("QRScout MECO")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("FRC match scouting with QR spreadsheet export")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Reset") { resetForm() }
            Button("Commit") { showCommitConfirmation = true }
                .fontWeight(.semibold)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.18)))
        .cornerRadius(8)
    }

    private var prematchSection: some View {
        AppSection(title: "Prematch") {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ScoutTextField(title: "Scout", text: $scoutName)
                    ScoutTextField(title: "Match", text: $matchNumber)
                    ScoutTextField(title: "Team", text: $teamNumber)
                }
                segmentedField(title: "Alliance", selection: $alliance, options: alliances)
                segmentedField(title: "Station", selection: $station, options: stations)
                ScoutTextField(title: "Robot notes", text: $robotNotes)
            }
        }
    }

    private var autonomousSection: some View {
        AppSection(title: "Autonomous") {
            VStack(spacing: 12) {
                CounterRow(title: "Auto Mobility", value: $autoMobility, range: 0...99)
                CounterRow(title: "Auto Fuel", value: $autoFuel, range: 0...99)
                CounterRow(title: "Auto Amp", value: $autoAmp, range: 0...99)
            }
        }
    }

    private var teleopSection: some View {
        AppSection(title: "Teleop") {
            VStack(spacing: 12) {
                CounterRow(title: "Teleop Speaker", value: $teleopSpeaker, range: 0...99)
                CounterRow(title: "Teleop Amp", value: $teleopAmp, range: 0...99)
                CounterRow(title: "Fed Pieces", value: $teleopFeed, range: 0...99)
                CounterRow(title: "Fouls", value: $fouls, range: 0...99)
                CounterRow(title: "Defense Rating", value: $defenseRating, range: 0...5)
            }
        }
    }

    private var endgameSection: some View {
        AppSection(title: "Endgame & Notes") {
            VStack(spacing: 10) {
                segmentedField(title: "Endgame", selection: $endgame, options: endgameOptions)
                TextEditor(text: $comments)
                    .frame(minHeight: 100)
                    .padding(6)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.35)))
            }
        }
    }

    private var outputSection: some View {
        AppSection(title: "QR Output") {
            VStack(spacing: 12) {
                QRCodeView(payload: payload)
                    .frame(width: 240, height: 240)
                    .padding(12)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.25)))

                Text(payload)
                    .font(.system(.footnote, design: .monospaced))
                    .lineLimit(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.35)))

                Text("Columns: \(columnNames.joined(separator: ","))")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func segmentedField(title: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }

    private func resetForm() {
        if let currentMatch = Int(matchNumber) {
            matchNumber = String(currentMatch + 1)
        }
        teamNumber = ""
        robotNotes = ""
        station = "1"
        endgame = "None"
        comments = ""
        autoMobility = 0
        autoFuel = 0
        autoAmp = 0
        teleopSpeaker = 0
        teleopAmp = 0
        teleopFeed = 0
        fouls = 0
        defenseRating = 0
    }

    private func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct AppSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.18)))
        .cornerRadius(8)
    }
}

private struct ScoutTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            TextField(title, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

private struct CounterRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.body)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: decrement) {
                Text("-")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(width: 42, height: 38)
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color.gray.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.35)))
            .cornerRadius(6)

            Text(String(value))
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.semibold)
                .frame(width: 44)

            Button(action: increment) {
                Text("+")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(width: 42, height: 38)
            }
            .buttonStyle(PlainButtonStyle())
            .background(Color.gray.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.35)))
            .cornerRadius(6)
        }
    }

    private func increment() {
        value = min(range.upperBound, value + 1)
    }

    private func decrement() {
        value = max(range.lowerBound, value - 1)
    }
}

private struct QRCodeView: View {
    let payload: String

    var body: some View {
        generatedImage
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .accessibility(label: Text("Scouting QR code"))
    }

    private var generatedImage: Image {
        guard let cgImage = makeQRCode(payload) else {
            return Image(systemName: "xmark.square")
        }
        return Image(decorative: cgImage, scale: 1.0, orientation: .up)
    }

    private func makeQRCode(_ text: String) -> CGImage? {
        guard let data = text.data(using: .isoLatin1),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        return CIContext().createCGImage(transformed, from: transformed.extent)
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
#endif
