# Error Handling

## Overview

Bridget implements a comprehensive error handling system that provides detailed error classification, graceful degradation, and user-friendly error recovery. The system is designed to handle errors at multiple levels while maintaining a smooth user experience.

## Error Classification System

### NetworkError Types

**NetworkError** represents errors that occur during network operations and HTTP communication.

#### `networkError`
**Description**: General network connectivity failures
**Causes**: 
- No internet connection
- DNS resolution failures
- Network timeouts
- Connection refused

**Recovery Strategy**:
- Automatic retry with exponential backoff
- Fallback to cached data if available
- User notification with retry option

#### `invalidResponse`
**Description**: Invalid or malformed HTTP responses
**Causes**:
- Non-HTTP responses
- Malformed response headers
- Invalid response structure

**Recovery Strategy**:
- Log detailed response information for debugging
- Retry with fresh connection
- Fallback to cached data

#### `httpError(statusCode: Int)`
**Description**: HTTP status code errors
**Common Status Codes**:
- `400`: Bad Request - Invalid API parameters
- `401`: Unauthorized - Authentication required
- `403`: Forbidden - Access denied
- `404`: Not Found - Resource not available
- `429`: Too Many Requests - Rate limiting
- `500`: Internal Server Error - Server-side issues
- `502`: Bad Gateway - Upstream service issues
- `503`: Service Unavailable - Service maintenance

**Recovery Strategy**:
- **4xx Errors**: User notification with clear error message
- **5xx Errors**: Automatic retry with backoff
- **Rate Limiting**: Implement exponential backoff
- **Service Unavailable**: Fallback to cached data

#### `invalidContentType`
**Description**: Unexpected content type in response
**Causes**:
- API returns HTML instead of JSON
- Missing or incorrect Content-Type header
- Server configuration issues

**Recovery Strategy**:
- Log response headers for debugging
- Retry with explicit Accept header
- Fallback to cached data

#### `payloadSizeError`
**Description**: Response payload too large or empty
**Causes**:
- Response exceeds 5MB limit
- Empty response body
- Malformed response structure

**Recovery Strategy**:
- Log payload size for monitoring
- Implement streaming for large responses
- Fallback to cached data

### BridgeDataError Types

**BridgeDataError** represents errors that occur during data processing and business logic operations.

#### `decodingError(DecodingError, rawData: Data)`
**Description**: JSON parsing and decoding failures
**Causes**:
- Invalid JSON syntax
- Missing required fields
- Type mismatches
- Date format errors

**Recovery Strategy**:
- Log raw data for debugging
- Implement flexible field parsing
- Skip invalid records and continue processing
- Fallback to sample data if all records fail

#### `processingError(String)`
**Description**: Business logic processing failures
**Causes**:
- Invalid bridge IDs
- Out-of-range dates
- Missing coordinate data
- Data validation failures

**Recovery Strategy**:
- Log detailed error context
- Filter out invalid records
- Continue processing with valid data
- Provide user feedback on data quality

## Error Propagation Flow

### 1. Error Detection
**Location**: Service layer components
**Detection Methods**:
- Network request failures
- JSON parsing exceptions
- Business logic validation
- Cache operation failures

### 2. Error Classification
**Process**: Categorize errors by type and severity
**Classification Criteria**:
- **Error Source**: Network, data, cache, business logic
- **Severity**: Critical, warning, info
- **Recoverability**: Automatic, manual, non-recoverable
- **User Impact**: High, medium, low

### 3. Error Context Preservation
**Information Captured**:
- Original error details
- Operation context (API endpoint, parameters)
- Timestamp and request ID
- User action that triggered error
- System state at time of error

### 4. Error Propagation
**Flow**: Service → AppStateModel → UI
**Propagation Method**:
- Error objects passed up through service hierarchy
- AppStateModel updated with error state
- UI automatically updates through Observation framework

### 5. User Notification
**Display Methods**:
- Alert dialogs for critical errors
- Inline error messages for recoverable errors
- Loading state indicators for transient errors
- Toast notifications for informational messages

## Error Recovery Strategies

### Automatic Recovery

#### Retry Logic
**Implementation**: Exponential backoff with jitter
**Retry Configuration**:
- **Initial Delay**: 1 second
- **Maximum Delay**: 30 seconds
- **Maximum Attempts**: 3 attempts
- **Backoff Multiplier**: 2x per attempt
- **Jitter**: ±25% random variation

**Retryable Errors**:
- Network connectivity issues
- HTTP 5xx server errors
- Temporary service unavailability
- Rate limiting responses

#### Cache Fallback
**Strategy**: Use cached data when network fails
**Cache Validation**:
- Check cache freshness (24-hour limit)
- Validate cache completeness
- Verify data schema version
- Ensure cache integrity

**Fallback Scenarios**:
- Network unavailable
- API service down
- Authentication failures
- Rate limiting exceeded

### Manual Recovery

#### User-Initiated Retry
**UI Elements**:
- Retry buttons in error dialogs
- Pull-to-refresh in list views
- Manual refresh in settings
- Force refresh options

**Retry Behavior**:
- Clear current error state
- Show loading indicators
- Attempt fresh data fetch
- Update UI with results

#### Error Reporting
**User Actions**:
- Report error to development team
- Share error details for debugging
- Provide feedback on error experience
- Request manual intervention

### Graceful Degradation

#### Partial Functionality
**Degradation Levels**:
- **Full Functionality**: All features available
- **Limited Functionality**: Core features with cached data
- **Basic Functionality**: Essential features only
- **Offline Mode**: Local data and basic navigation

#### Feature Availability
**Always Available**:
- View cached route data
- Basic navigation
- Settings and preferences
- Error reporting

**Network Dependent**:
- Fresh data updates
- Real-time information
- Advanced features
- Analytics and logging

## Error Monitoring and Analytics

### Error Tracking
**Metrics Collected**:
- Error frequency by type
- Error distribution by user segment
- Error correlation with app usage
- Error resolution time

**Debug Information**:
- Stack traces and call stacks
- Request/response details
- System state information
- User interaction context

### Performance Impact
**Monitoring Areas**:
- Error handling overhead
- Retry mechanism performance
- Cache fallback efficiency
- User experience impact

### Alerting and Notifications
**Alert Thresholds**:
- High error rates (>5% of requests)
- Critical error patterns
- Service degradation indicators
- User experience impact metrics

## User Experience Considerations

### Error Message Design
**Principles**:
- **Clear and Concise**: Simple, understandable language
- **Actionable**: Provide clear next steps
- **Non-Technical**: Avoid technical jargon
- **Helpful**: Offer solutions when possible

**Message Examples**:
- ✅ "Unable to load bridge data. Please check your connection and try again."
- ❌ "HTTP 500 Internal Server Error occurred during API request"

### Loading States
**Implementation**:
- Show loading indicators during retries
- Provide progress feedback for long operations
- Indicate when using cached data
- Show background refresh status

### Error Prevention
**Strategies**:
- Validate input before network requests
- Implement request debouncing
- Use optimistic UI updates
- Provide offline indicators

## Testing Error Scenarios

### Unit Testing
**Test Cases**:
- Network error simulation
- JSON parsing failures
- Business logic validation errors
- Cache operation failures

**Testing Tools**:
- Mock network responses
- Invalid data injection
- Error condition simulation
- Recovery mechanism validation

### Integration Testing
**Test Scenarios**:
- Real API error responses
- Network connectivity issues
- Cache corruption scenarios
- End-to-end error flows

### UI Testing
**User Flows**:
- Error message display
- Retry button functionality
- Loading state transitions
- Error recovery success

## Best Practices

### Error Handling Guidelines
1. **Always Handle Errors**: Never let errors crash the app
2. **Provide Context**: Include relevant information for debugging
3. **Graceful Degradation**: Maintain functionality when possible
4. **User-Friendly Messages**: Avoid technical jargon
5. **Recovery Options**: Always provide a path forward
6. **Logging**: Comprehensive error logging for debugging
7. **Monitoring**: Track error patterns and trends
8. **Testing**: Thorough testing of error scenarios

### Code Examples

#### Error Handling in Services
```swift
do {
    let data = try await networkClient.fetchData()
    let processedData = try bridgeDataProcessor.process(data)
    return processedData
} catch NetworkError.networkError {
    // Handle network connectivity issues
    throw BridgeDataError.processingError("Network unavailable")
} catch NetworkError.httpError(let statusCode) {
    // Handle HTTP status errors
    throw BridgeDataError.processingError("Server error: \(statusCode)")
} catch {
    // Handle unexpected errors
    throw BridgeDataError.processingError("Unexpected error: \(error.localizedDescription)")
}
```

#### Error Recovery in UI
```swift
if let error = appState.error {
    Alert(
        title: Text("Error"),
        message: Text(error.localizedDescription),
        primaryButton: .default(Text("Retry")) {
            Task {
                await appState.loadData()
            }
        },
        secondaryButton: .cancel()
    )
}
```

## Future Enhancements

### Planned Improvements
- **Advanced Retry Logic**: Circuit breaker pattern
- **Error Analytics**: Detailed error reporting dashboard
- **Predictive Error Prevention**: ML-based error prediction
- **Enhanced Recovery**: Automatic problem resolution
- **User Feedback Integration**: Error reporting with user context 