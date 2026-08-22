//
//  StoredVerseAnnotationTests.swift
//  SwiftBibleTests
//
//  Created by Brandon Thomas on 2026-07-12.
//

import Foundation
import Testing
import SwiftData
@testable import SwiftBible

struct StoredVerseAnnotationTests {

    /// insert + fetch a tag
    @Test func insertAndFetchTag() throws {
        let modelContainer: ModelContainer = try buildModelContainer()
        let storedTagFetchDescriptor = FetchDescriptor<StoredTag>()

        let tag: StoredTag = .init(id: UUID(),
                                   displayName: "Tag",
                                   normalizedName: "tag")
        
        // Stage changes into context (dont "commit" yet)
        let modelContext1: ModelContext = .init(modelContainer)

        modelContext1.insert(tag)
        #expect(modelContext1.hasChanges)
        
        // Flush staged changes into store
        try modelContext1.save()
        
        // Ensure it saved
        // - .contains(storedTag) will fail for ctx1/both lookups due to SwiftData returning
        //   different pointers for different objects (in-memory SQLite DB essentially); our
        //   Swift object is NOT in the store but rather a materialized view of a row... the
        //   class instance is built on-demand. This is why we have to compare ID rather than
        //   our local class itself. Basically C# DbContext.
        // TLDR: == on @Model objects compares pointers (SwiftData rows) rather than objects
        //   themselves.
        let fetchResultsForCtx1 = try modelContext1.fetch(storedTagFetchDescriptor)
        #expect(fetchResultsForCtx1.contains { $0.id == tag.id })
        
        // Fetch from another ModelContext instance to prove store-read persistence (throw out
        // in-memory cases for this test)
        // - Empty descriptor means all of this type
        let modelContext2: ModelContext = .init(modelContainer)
        
        let fetchResultsForCtx2 = try modelContext2.fetch(storedTagFetchDescriptor)
        #expect(fetchResultsForCtx2.contains { $0.id == tag.id })
    }
    
    /// insert + fetch a StoredVerseAnnotation
    @Test func insertAndFetchVerseAnnotation() throws {
        let modelContainer: ModelContainer = try buildModelContainer()
        let storedAnnotationFetchDescriptor = FetchDescriptor<StoredVerseAnnotation>()

        let annotation: StoredVerseAnnotation = .init(id: UUID(),
                                                      translationID: 123,
                                                      bookCode: "GEN",
                                                      chapter: 1,
                                                      startVerse: 1,
                                                      highlightColor: .blue,
                                                      createdAt: Date.now)
        
        // Stage changes into context (dont "commit" yet)
        let modelContext1: ModelContext = .init(modelContainer)

        modelContext1.insert(annotation)
        #expect(modelContext1.hasChanges)
        
        // Flush staged changes into store
        try modelContext1.save()
        
        // Ensure it saved
        let fetchResultsForCtx1 = try modelContext1.fetch(storedAnnotationFetchDescriptor)
        #expect(fetchResultsForCtx1.contains {
            $0.id == annotation.id
            && $0.highlightColor == .blue
        })
        
        // Fetch from another ModelContext instance to prove store-read persistence (throw out
        // in-memory cases for this test)
        // - Empty descriptor means all of this type
        let modelContext2: ModelContext = .init(modelContainer)
        
        let fetchResultsForCtx2 = try modelContext2.fetch(storedAnnotationFetchDescriptor)
        #expect(fetchResultsForCtx2.contains {
            $0.id == annotation.id
            && $0.highlightColor == .blue
        })
    }
    
    /// insert + fetch a StoredVerseAnnotation
    @Test func relationshipSurvivesSwiftDataSaveAndFetch() throws {
        let modelContainer: ModelContainer = try buildModelContainer()
        let storedAnnotationFetchDescriptor = FetchDescriptor<StoredVerseAnnotation>()
        
        // Set up test data
        let tag: StoredTag = .init(id: UUID(),
                                   displayName: "Tag",
                                   normalizedName: "tag")

        let annotation: StoredVerseAnnotation = .init(id: UUID(),
                                                      translationID: 123,
                                                      bookCode: "GEN",
                                                      chapter: 1,
                                                      startVerse: 1,
                                                      highlightColor: .blue,
                                                      createdAt: Date.now)
        
        annotation.tags = [tag]
        
        // Stage changes into context (dont "commit" yet)
        let modelContext1: ModelContext = .init(modelContainer)

        modelContext1.insert(annotation)
        #expect(modelContext1.hasChanges)
        
        // Flush staged changes into store
        try modelContext1.save()
        
        // Ensure it saved
        // unwrap optional using #require; throw if nil
        let annotationsForCtx1 = try modelContext1.fetch(storedAnnotationFetchDescriptor)
        
        let fetchedAnnotation = try #require(annotationsForCtx1.first { $0.id == annotation.id })
        #expect(fetchedAnnotation.highlightColor == .blue)
        
        let fetchedAnnotationTag = try #require(fetchedAnnotation.tags?.first { $0.id == tag.id })
        #expect(fetchedAnnotationTag.id == tag.id)
        #expect(fetchedAnnotationTag.annotations?.contains { $0.id == annotation.id } == true)
    }
    
    /// test container/store w/ real schema resolution but only backed by memory;
    /// nothing hits disk and each container starts empty
    private func buildModelContainer() throws -> ModelContainer {
        let typesToRegister: [any PersistentModel.Type] = [
            StoredVerseAnnotation.self,
            StoredTag.self
        ]
        
        let schema: Schema = .init(typesToRegister)
        let modelConfiguration = ModelConfiguration(schema: schema,
                                                    isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema,
                                  configurations: [modelConfiguration])
    }
}
