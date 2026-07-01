//
//  YouVersionPassageResponseTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 6/30/26.
//

import Foundation
import Testing
@testable import SwiftBible

struct YouVersionPassageResponseTests {

    private let htmlContent: String = """
        <div>
            <div class="p">
                <span class="yv-v" v="1"></span><span class="yv-vlbl">1</span>In the beginning
                <span class="yv-n f"><span class="fr">1:1</span><span class="ft"> </span><span class="ft">A footnote.</span></span>
                the Living Expression was already there.
            </div>
            <div class="q1">
                And the Living Expression was with God, yet fully God.
                <span class="ref" usfm="COL.1.15+COL.1.16">Col. 1:15-16</span>
            </div>
        </div>
        """

    /// Attempt to parse test JSON via YouVersionPassageResponse mapping
    @Test func mapperFunctionsSucceed() {
        let passageResponse: [String: String] = [
            "id": "JHN.1",
            "content": htmlContent,
            "reference": "John 1"
        ]

        guard JSONSerialization.isValidJSONObject(passageResponse) else {
            #expect(Bool(false), "`passageResponse` should be valid JSON")
            return
        }

        do {
            let responseData = try JSONSerialization.data(withJSONObject: passageResponse)
            let jsonDecoder: JSONDecoder = .init()
            let decodedPassage: YouVersionPassageResponse = try jsonDecoder.decode(YouVersionPassageResponse.self,
                                                                                   from: responseData)
            let passage: Passage = decodedPassage.passageForApp()

            #expect(!decodedPassage.id.isEmpty)
            #expect(!decodedPassage.htmlContent.isEmpty)
            #expect(!decodedPassage.reference.isEmpty)

            #expect(passage.id == "JHN.1")
            #expect(passage.reference == "John 1")
            #expect(passage.htmlContent.contains("yv-vlbl"))
            #expect(passage.htmlContent.contains("yv-n f"))
        } catch {
            #expect(Bool(false), "Failed to decode `passageResponse`: \(error.localizedDescription)")
        }
    }

}
