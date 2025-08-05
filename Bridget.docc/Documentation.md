# Bridget

A SwiftUI app for Seattle bridge route optimization using historical data and real-time traffic analysis.

## Overview

Bridget is a route optimization app that helps users navigate Seattle's drawbridges by providing historical opening data and real-time traffic analysis. The app integrates with the Seattle Open Data API to fetch historical bridge opening records and uses machine learning for route optimization.

## Topics

### Essentials

- <doc:AppStateModel>
- <doc:BridgeStatusModel>
- <doc:RouteModel>

### Services

- <doc:BridgeDataService>
- <doc:NetworkClient>
- <doc:CacheService>
- <doc:BridgeDataProcessor>
- <doc:SampleDataProvider>

### Views

- <doc:RouteListView>
- <doc:ContentView>

## Architecture

Bridget follows a modular architecture with clear separation of concerns:

- **Models**: Observable data models for bridge status, routes, and app state
- **Services**: Specialized services for data fetching, caching, and processing
- **Views**: SwiftUI views that display data and handle user interactions

The app uses Apple's Observation framework for reactive UI updates and implements a cache-first strategy for reliable data access.

## Key Features

- Historical bridge opening data from Seattle Open Data API
- Real-time traffic analysis and route optimization
- Offline caching for reliable data access
- Machine learning-powered route scoring
- Reactive UI updates using Observation framework

## Getting Started

To use Bridget, simply launch the app and it will automatically load historical bridge data. The app will display available routes and their optimization scores based on historical opening patterns.

For development and testing, the app includes sample data providers that generate realistic mock data for testing scenarios. 