defmodule ExSip.Clients.UDP do
  require Logger

  use GenStateMachine, callback_mode: [:handle_event_function, :state_enter]

  alias ExSip.Clients.Handler
  alias ExSip.Message
  alias ExSip.Clients.State

  import ExSip.ErrorLogger

  def stop(pid, reason \\ :normal, timeout \\ :infinity) do
    GenStateMachine.stop(pid, reason, timeout)
  end

  def start_link(options, gen_options \\ []) do
    options = extract_start_options!(options)
    GenStateMachine.start_link(__MODULE__, options, gen_options)
  end

  def start(options, gen_options \\ []) do
    options = extract_start_options!(options)
    GenStateMachine.start(__MODULE__, options, gen_options)
  end

  @impl true
  def init(options) do
    {handler, args} = Keyword.fetch!(options, :handler)

    state = %State{
      handler: handler,
    }
    case Handler.init(args, state) do
      {:ok, state} ->
        {:ok, :open, state}
    end
  rescue ex ->
    log_error_and_reraise(ex, __STACKTRACE__)
  end

  defp extract_start_options!(options) do
    {handler, args} = Keyword.fetch!(options, :handler)

    [
      handler: {handler, args},
    ]
  end
end
