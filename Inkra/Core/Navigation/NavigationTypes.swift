//
//  NavigationTypes.swift
//  Inkra
//
//  Navigation types used throughout the app
//

import Foundation

// Navigation target enum for different destinations
enum ProjectNavigationTarget: Hashable {
    case interview(Project)
    case transcript(Project)
    case questionsAndAnswers(Project)
}

// Navigation source enum to track where ProjectDetailView was accessed from
enum ProjectNavigationSource {
    case home
    case myInterviews
}