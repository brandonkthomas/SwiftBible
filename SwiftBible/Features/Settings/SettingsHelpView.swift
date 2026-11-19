//
//  SettingsHelpView.swift
//  SwiftBible
//
//  Created by Brandon Thomas on 2026-11-18.
//

import SwiftUI

struct SettingsHelpView: View {

    private static let address = "feedback@brandonthomas.net"
    private static let privacyPolicyURL = "https://github.com/brandonkthomas/SwiftBible/blob/main/Public/Privacy-Policy.md"

    /// Alert steps for the "Report an Issue" flow, in presentation order
    private enum ReportStep {
        case type
        case summary
        case steps
        case expected
        case actual
    }

    private enum FeedbackType: String {
        case bug = "Bug"
        case featureRequest = "Feature Request"
        case other = "Other"
    }

    @State private var reportStep: ReportStep?
    @State private var feedbackType: FeedbackType = .bug
    @State private var summary = ""
    @State private var stepsToReproduce = ""
    @State private var expectedResult = ""
    @State private var actualResult = ""

    /// Main body
    var body: some View {
        List {
            // SUPPORT
            Section {
                // Contact
                Button {
                    guard let url = URL(string: "mailto:\(Self.address)") else { return }
                    UIApplication.shared.open(url)
                } label: {
                    HStack{
                        Image(systemName: "envelope.fill")
                            .frame(width: 25)
                        Text("Contact")
                            .padding(.leading, 8)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(.accent)

                // Report an Issue
                Button {
                    startReport()
                } label: {
                    HStack{
                        Image(systemName: "exclamationmark.triangle.fill")
                            .frame(width: 25)
                        Text("Report an Issue")
                            .padding(.leading, 8)
                        Spacer()
                    }
                }
                .foregroundStyle(.accent)
            } header: {
                Text("Support")
            }

            // LEGAL
            Section {
                // Privacy Policy
                Button {
                    guard let url = URL(string: Self.privacyPolicyURL) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    HStack{
                        Image(systemName: "lock.document.fill")
                            .frame(width: 25)
                        Text("Privacy Policy")
                            .padding(.leading, 8)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(.accent)
            } header: {
                Text("Legal")
            }
        }
        .navigationTitle("Help & Support")
        .alert("Report an Issue", isPresented: isPresenting(.type)) {
            Button("Issue") { selectType(.bug) }
            Button("Feature Request") { selectType(.featureRequest) }
            Button("Other") { selectType(.other) }
            Button("Cancel", role: .cancel) { reportStep = nil }
        } message: {
            Text("What kind of feedback do you have?")
        }
        .alert("Summary", isPresented: isPresenting(.summary)) {
            TextField("Summary", text: $summary)
            Button("Next") {
                if feedbackType == .bug {
                    reportStep = .steps
                } else {
                    finishReport()
                }
            }
            Button("Cancel", role: .cancel) { reportStep = nil }
        } message: {
            Text("Briefly describe your feedback.")
        }
        .alert("Steps to Reproduce", isPresented: isPresenting(.steps)) {
            TextField("Steps", text: $stepsToReproduce)
            Button("Next") { reportStep = .expected }
            Button("Cancel", role: .cancel) { reportStep = nil }
        } message: {
            Text("What did you do before the issue occurred?")
        }
        .alert("Expected Result", isPresented: isPresenting(.expected)) {
            TextField("Expected result", text: $expectedResult)
            Button("Next") { reportStep = .actual }
            Button("Cancel", role: .cancel) { reportStep = nil }
        } message: {
            Text("What did you expect to happen?")
        }
        .alert("Actual Result", isPresented: isPresenting(.actual)) {
            TextField("Actual result", text: $actualResult)
            Button("Done") { finishReport() }
            Button("Cancel", role: .cancel) { reportStep = nil }
        } message: {
            Text("What actually happened?")
        }
    }

    /// Binding for a single step's alert. Dismissal only clears the step if a button
    /// action hasn't already advanced to the next one, so alerts can chain.
    private func isPresenting(_ step: ReportStep) -> Binding<Bool> {
        Binding(
            get: { reportStep == step },
            set: { isPresented in
                if !isPresented && reportStep == step {
                    reportStep = nil
                }
            }
        )
    }

    private func startReport() {
        feedbackType = .bug
        summary = ""
        stepsToReproduce = ""
        expectedResult = ""
        actualResult = ""
        reportStep = .type
    }

    private func selectType(_ type: FeedbackType) {
        feedbackType = type
        reportStep = .summary
    }

    private func finishReport() {
        reportStep = nil
        guard let url = feedbackMailtoURL() else { return }
        UIApplication.shared.open(url)
    }

    /// Feedback email, mirrored from the brandonthomas.net/contact/swiftbible template
    private func feedbackMailtoURL() -> URL? {
        let subject = "SwiftBible Feedback"
        var body = """
            Feedback type (bug, feature request, other): \(feedbackType.rawValue)

            Summary: \(summary)

            """
        if feedbackType == .bug {
            body += """
                Steps to reproduce:
                \(stepsToReproduce)

                Expected result: \(expectedResult)

                Actual result: \(actualResult)

                """
        }
        body += """
            Device: \(Self.deviceModel)
            iOS version: \(UIDevice.current.systemVersion)
            SwiftBible version: \(Self.appVersion)
            """
        // RFC 6068: line breaks in a mailto body are percent-encoded CRLF
        body = body.replacingOccurrences(of: "\n", with: "\r\n")

        // Encode everything except unreserved characters so "&", "=", etc. can't break the query
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "mailto:\(Self.address)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    /// Hardware identifier such as "iPhone17,1"; UIDevice.model only returns "iPhone"
    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsHelpView()
    }
}

