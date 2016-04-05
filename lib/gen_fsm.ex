defmodule GenFSM do
  @type state_name :: atom
  @type state_data :: term
  @type next_state_name :: atom
  @type new_state_data :: term
  @type reason :: term

  @callback init(args :: term) ::
    {:ok, state_name, state_data} |
    {:ok, state_name, state_data, timeout | :hibernate} |
    :ignore |
    {:stop, reason}

  @callback handle_event(event :: term, state_name, state_data) ::
    {:next_state, next_state_name, new_state_data} |
    {:next_state, next_state_name, new_state_data, timeout} |
    {:next_state, next_state_name, new_state_data, :hibernate} |
    {:stop, reason, new_state_data} when new_state_data: term

  @type reply :: term
  @callback handle_sync_event(event :: term, from :: {pid, tag :: term}, state_name, state_data) ::
    {:reply, reply, next_state_name, new_state_data} |
    {:reply, reply, next_state_name, new_state_data, timeout} |
    {:reply, reply, next_state_name, new_state_data, :hibernate} |
    {:next_state, next_state_name, new_state_data} |
    {:next_state, next_state_name, new_state_data, timeout} |
    {:next_state, next_state_name, new_state_data, :hibernate} |
    {:stop, reason, reply, new_state_data} |
    {:stop, reason, new_state_data} when new_state_data: term

  @callback handle_info(info :: term, state_name, state_data) ::
    {:next_state, next_state_name, new_state_data} |
    {:next_state, next_state_name, new_state_data, timeout} |
    {:next_state, next_state_name, new_state_data, :hibernate} |
    {:stop, reason, new_state_data} when new_state_data: term

  @callback terminate(reason, state_name, state_data) ::
    term when reason: :normal | :shutdown | {:shutdown, term} | term

  @callback code_change(old_vsn, state_name, state_data, extra :: term) ::
    {:ok, next_state_name, new_state_data} |
    {:error, reason} when old_vsn: term |
    {:down, term}

  @typedoc "Return values of `start*` functions"
  @type on_start :: {:ok, pid} | :ignore | {:error, {:already_started, pid} | term}

  @typedoc "Options used by the `start*` functions"
  @type options :: [option]

  @typedoc "Option values used by the `start*` functions"
  @type option :: {:debug, debug} |
                  {:name, name} |
                  {:timeout, timeout} |
                  {:spawn_opt, Process.spawn_opt}

  @typedoc "The GenFSM name"
  @type name :: atom | {:global, term} | {:via, module, term}

  @typedoc "Debug options supported by the `start*` functions"
  @type debug :: [:trace | :log | :statistics | {:log_to_file, Path.t} | {:install, {fun, any}}]

  @typedoc "The fsm reference"
  @type fsm_ref :: name | {name, node} | pid()

  @spec start_link(module, any, options) :: on_start
  def start_link(module, args, options \\ []) when is_atom(module) and is_list(options) do
    do_start(:link, module, args, options)
  end

  @spec start(module, any, options) :: on_start
  def start(module, args, options \\ []) when is_atom(module) and is_list(options) do
    do_start(:nolink, module, args, options)
  end

  defp do_start(link, module, args, options) do
    case Keyword.pop(options, :name) do
      {nil, opts} ->
        :gen.start(:gen_fsm, link, module, args, opts)
      {atom, opts} when is_atom(atom) ->
        :gen.start(:gen_fsm, link, {:local, atom}, module, args, opts)
      {other, opts} when is_tuple(other) ->
        :gen.start(:gen_fsm, link, other, module, args, opts)
    end
  end

  @spec stop(fsm_ref, reason :: term, timeout) :: :ok
  def stop(fsm, reason \\ :normal, timeout \\ :infinity) do
    :gen.stop(fsm, reason, timeout)
  end

  defdelegate [
    sync_send_event(fsm_ref, event),
    sync_send_event(fsm_ref, event, timeout),
    sync_send_all_state_event(fsm_ref, event),
    sync_send_all_state_event(fsm_ref, event, timeout),
    send_event(fsm_ref, event),
    send_all_state_event(fsm_ref, event),
    reply(caller, reply),
    send_event_after(time, event),
    start_timer(time, message),
    cancel_timer(timer_ref)
  ], to: :gen_fsm

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour :gen_fsm

      @doc false
      def handle_event(_event, _state_name, state_data) do
        {:stop, :unexpected_event, state_data}
      end

      @doc false
      def handle_sync_event(_event, _from, _state_name, state_data) do
        {:stop, :unexpected_event, state_data}
      end

      @doc false
      def handle_info(_info, _state_name, state_data) do
        {:stop, :unexpected_message, state_data}
      end

      @doc false
      def terminate(reason, _state_name, _state_data) do
        reason
      end

      @doc false
      def code_change(_old, state_name, state_data, _extra) do
        {:ok, state_name, state_data}
      end

      defoverridable [handle_event: 3, handle_sync_event: 4,
                      handle_info: 3, terminate: 3, code_change: 4]
    end
  end
end
