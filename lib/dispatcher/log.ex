defmodule Dispatcher.Log do
  @type log_name ::
          :log_layer_start_processing
          | :log_layer_matching

  @spec log(log_name, any()) :: any()
  def log(name, content) do
    if Application.get_env(:dispatcher, name) do
      IO.puts(content)
    else
      :ok
    end
  end

  @spec inspect(any(), log_name, any()) :: any()
  def inspect(content, name, opts \\ []) do
    if Application.get_env(:dispatcher, name) do
      transform = Keyword.get(opts, :transform, fn x -> x end)

      content
      |> transform.()
      |> IO.inspect(Keyword.delete(opts, :transform))
    end

    content
  end
end
