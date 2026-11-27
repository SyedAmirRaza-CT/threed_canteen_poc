/// Loading / success / error state for async work. Used instead of `bool isLoading`.
sealed class ApiState<T> {
  const ApiState();
}

class ApiInitial<T> extends ApiState<T> {
  const ApiInitial();
}

class ApiLoading<T> extends ApiState<T> {
  const ApiLoading();
}

class ApiSuccess<T> extends ApiState<T> {
  const ApiSuccess(this.data);
  final T data;
}

class ApiError<T> extends ApiState<T> {
  const ApiError(this.message);
  final String message;
}
