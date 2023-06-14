defmodule ExSip.ErrorLogger do
  defmacro log_error(ex, stacktrace) do
    quote do
      Logger.error Exception.format(:error, unquote(ex), unquote(stacktrace))
    end
  end

  defmacro log_error_and_reraise(ex, stacktrace) do
    quote do
      Logger.error Exception.format(:error, unquote(ex), unquote(stacktrace))
      reraise unquote(ex), unquote(stacktrace)
    end
  end
end
