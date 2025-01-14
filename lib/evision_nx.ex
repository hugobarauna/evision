defmodule Evision.Nx do
  @moduledoc """
  OpenCV's cv::mat to Nx tensor.
  """

  import Evision.Errorize

  unless Code.ensure_loaded?(Nx) do
    @compile {:no_warn_undefined, Nx}
  end

  @doc """
  Transform an `Evision.Mat` reference to `Nx.tensor`.

  The resulting tensor is in the shape `{height, width, channels}`.

  ### Example

  ```elixir
  iex> {:ok, mat} = Evision.imread("/path/to/exist/img.png")
  iex> nx_tensor = Evision.Nx.to_nx(mat)
  #Nx.Tensor<
    u8[1080][1920][3]
    [[ ... pixel data ... ]]
  >
  ```

  """
  @doc namespace: :external
  @spec to_nx(Evision.Mat.t(), module()) :: Nx.Tensor.t() | {:error, String.t()}
  def to_nx(mat, backend \\ Evision.Backend) when is_struct(mat, Evision.Mat) do
    with {:ok, mat_type} <- Evision.Mat.type(mat),
         {:ok, mat_shape} <- Evision.Mat.shape(mat),
         {:ok, bin} <- Evision.Mat.to_binary(mat) do
      bin
      |> Nx.from_binary(mat_type, backend: backend)
      |> Nx.reshape(mat_shape)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  deferror(to_nx(mat))
  deferror(to_nx(mat, backend))

  @doc """
  Converts a tensor from `Nx.Tensor` to `Evision.Mat`.
  """
  @doc namespace: :external
  @spec to_mat(Nx.t()) :: {:ok, Evision.Mat.t()} | {:error, String.t()}
  def to_mat(t) when is_struct(t, Nx.Tensor) do
    case Nx.shape(t) do
      {} ->
        Evision.Mat.from_binary_by_shape(Nx.to_binary(t), Nx.type(t), {1})

      shape ->
        Evision.Mat.from_binary_by_shape(Nx.to_binary(t), Nx.type(t), shape)
    end
  end

  deferror(to_mat(t))

  @doc namespace: :external
  def to_mat(t, as_shape) when is_struct(t, Nx.Tensor) do
    case Nx.shape(t) do
      {} ->
        Evision.Mat.from_binary_by_shape(Nx.to_binary(t), Nx.type(t), {1})

      shape ->
        if Tuple.product(shape) == Tuple.product(as_shape) do
          Evision.Mat.from_binary_by_shape(Nx.to_binary(t), Nx.type(t), as_shape)
        else
          {:error, "cannot convert tensor(#{inspect(shape)}) to mat as shape #{inspect(as_shape)}"}
        end
    end
  end

  deferror(to_mat(t, as_shape))

  @doc namespace: :external
  def to_mat(binary, type, rows, cols, channels) do
    Evision.Mat.from_binary(binary, type, rows, cols, channels)
  end

  deferror(to_mat(binary, type, rows, cols, channels))

  @doc namespace: :external
  @doc """
  Converts a tensor from `Nx.Tensor` to `Evision.Mat`.

  If the tuple size of the shape is 3, the resulting `Evision.Mat` will be a `c`-channel 2D image,
  where `c` is the last number in the shape tuple.

  If the tuple size of the shape is 2, the resulting `Evision.Mat` will be a 1-channel 2D image.

  Otherwise, it's not possible to convert the tensor to a 2D image.
  """
  @spec to_mat_2d(Nx.t()) :: {:ok, Evision.Mat.t()} | {:error, String.t()}
  def to_mat_2d(t) do
    case Nx.shape(t) do
      {height, width} ->
        Evision.Mat.from_binary(Nx.to_binary(t), Nx.type(t), height, width, 1)
      {height, width, channels} ->
        Evision.Mat.from_binary(Nx.to_binary(t), Nx.type(t), height, width, channels)
      shape ->
        {:error, "Cannot convert tensor(#{inspect(shape)}) to a 2D image"}
    end
  end

  deferror(to_mat_2d(t))
end
