defmodule ExSip.Proplist do
  @moduledoc """
  A hybrid of erlang's proplists and lists keystores.

  It acts as a Set for key-value pairs, but stil maintains it's order like a List.

  Copied from pepper_http, which was copied from elixir-mail, which is licensed as MIT.

  Note that many of the original functions in this module will de-duplicate lists.

  For SIP that is likely a bad thing since it could remove important Via headers as a side-effect.

  This module is provided purely for convenience.
  """

  @type key :: term()

  @type value :: term()

  @type t :: [{key(), value()} | term]

  @doc """
  Retrieves all keys from the key value pairs present in the list,
  unlike :proplists.get_keys which will return non-kv pairs as keys

  Args:
  * `list` - a list to retrieve all the keys from
  """
  @spec keys(t()) :: [key()]
  def keys(list) do
    Enum.reduce(list, [], fn
      {key, _value}, acc ->
        if Enum.member?(acc, key) do
          acc
        else
          [key | acc]
        end

      _value, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  @doc """
  Detects if the list contains the specified key.

  Args:
  * `list` - the list to look in
  * `key` - the key to look for
  """
  @spec has_key?(t(), key()) :: boolean()
  def has_key?(list, key) do
    Enum.any?(list, fn
      {k, _value} ->
        key == k

      _value ->
        false
    end)
  end

  @doc """
  Stores a key-value pair in the list, will replace an existing pair with the
  same key.

  Args:
  * `list` - the list to store in
  * `key` - the key of the pair
  * `value` - the value of the pair
  """
  @spec put(t(), key(), value()) :: t()
  def put(list, key, value) do
    :lists.keystore(key, 1, list, {key, value})
  end

  @doc """
  Prepends the key-value pair to the list if it doesn't already exist, otherwise
  it will replace the existing pair

  Args:
  * `list` - the list to store in
  * `key` - the key of the pair
  * `value` - the value of the pair
  """
  @spec prepend(t(), key(), value()) :: t()
  def prepend(list, key, value) do
    if has_key?(list, key) do
      # replace the existing pair
      put(list, key, value)
    else
      prepend_dup(list, key, value)
    end
  end

  @doc """
  Prepends the key-value pair to the list, even if it already exists.

  Args:
  * `list` - the list to store in
  * `key` - the key of the pair
  * `value` - the value of the pair
  """
  @spec prepend_dup(t(), key(), value()) :: t()
  def prepend_dup(list, key, value) do
    [{key, value} | list]
  end

  @doc """
  Prepends the key-value pair to the list by local to keys of the same if they exist

  Args:
  * `list` - the list to store in
  * `key` - the key of the pair
  * `value` - the value of the pair
  """
  @spec prepend_local(t(), key(), value()) :: t()
  def prepend_local(list, key, value) do
    do_prepend_local(list, key, value, [])
  end

  defp do_prepend_local([], key, value, acc) do
    [{key, value} | Enum.reverse(acc)]
  end

  defp do_prepend_local([{key, _old_value} | _] = rest, key, value, acc) do
    Enum.reverse(acc) ++ [{key, value} | rest]
  end

  defp do_prepend_local([pair | rest], key, value, acc) do
    do_prepend_local(rest, key, value, [pair | acc])
  end

  @doc """
  Appends the key-value pair to the list by local to keys of the same if they exist

  Args:
  * `list` - the list to store in
  * `key` - the key of the pair
  * `value` - the value of the pair
  """
  @spec append_local(t(), key(), value()) :: t()
  def append_local(list, key, value) do
    Enum.reverse(prepend_local(Enum.reverse(list), key, value))
  end

  @doc """
  Retrieves a value from the list

  Args:
  * `list` - the list to look in
  * `key` - the key of the pair to retrieve it's value
  """
  @spec get(t(), key()) :: value()
  def get(list, key) do
    case :proplists.get_value(key, list) do
      :undefined ->
        nil

      value ->
        value
    end
  end

  @doc """
  Return a list of all values with the specified key

  Args:
  * `list` - the list to retrieve items from
  * `key` - the key of the pair to retrieve
  """
  @spec all(t(), key()) :: [value()]
  def all(list, key) when is_list(list) do
    list
    |> Enum.reduce([], fn
      {^key, value}, acc ->
        [value | acc]

      ^key, acc ->
        [key | acc]

      _, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  @doc """
  Merges duplicate pairs with the latest value.

  Args:
  * `list` - the list to normalize
  """
  @spec normalize(t()) :: t()
  def normalize(list) when is_list(list) do
    Enum.reduce(list, [], fn
      {key, value}, acc ->
        if has_key?(acc, key) do
          put(acc, key, value)
        else
          [{key, value} | acc]
        end

      value, acc ->
        [value | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Concatentates the given lists.

  Args:
  * `a` - base list to merge unto
  * `b` - list to merge with
  """
  @spec merge(a :: t(), b :: t()) :: t()
  def merge(a, b) do
    Enum.reduce(b, Enum.reverse(a), fn
      {key, v}, acc ->
        prepend(acc, key, v)

      value, acc ->
        [value | acc]
    end)
    |> Enum.reverse()
  end

  @doc """
  Removes a key-value pair by the given key and returns the remaining list

  Args:
  * `list` - the list to remove the pair from
  * `key` - the key to remove
  """
  @spec delete(t(), key()) :: t()
  def delete(list, key) when is_list(list) do
    :proplists.delete(key, list)
  end

  @doc """
  Filters the proplist, i.e. returns only those elements
  for which `fun` returns a truthy value.

  Args:
  * `list` - the list to filter
  * `func` - the function to execute
  """
  @spec filter(t(), func :: any) :: t()
  def filter(list, func) when is_list(list) do
    Enum.filter(list, fn
      {_key, _value} = value ->
        func.(value)

      _value ->
        true
    end)
  end

  @doc """
  Drops the specified keys from the list, returning the remaining.

  Args:
  * `list` - the list
  * `keys` - the keys to remove
  """
  @spec drop(t(), keys :: [key()]) :: t()
  def drop(list, keys) when is_list(list) do
    filter(list, fn {key, _value} ->
      !Enum.member?(keys, key)
    end)
  end

  @doc """
  Takes the specified keys from the list, returning the remaining.

  Args:
  * `list` - the list
  * `keys` - the keys to keep
  """
  @spec take(t(), keys :: [key()]) :: t()
  def take(list, keys) when is_list(list) do
    filter(list, fn {key, _value} ->
      Enum.member?(keys, key)
    end)
  end
end
