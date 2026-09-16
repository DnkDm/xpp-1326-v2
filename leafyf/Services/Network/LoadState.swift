import Foundation

/// The four states every remote screen in Leafy moves through.
///
/// Modelled as one enum rather than a pile of `isLoading` / `error` / `value` flags, so a
/// view can never render "loading" and "failed" at the same time.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(APIError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var error: APIError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

extension LoadState: Equatable where Value: Equatable {}
