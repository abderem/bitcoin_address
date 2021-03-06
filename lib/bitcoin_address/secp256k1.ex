defmodule BitcoinAddress.Secp256k1 do
  @moduledoc """
  Utility module to deal with functionality around secp265k1
  Elliptic Point Cryptography. Specifically,

  - Generating a secp256k1 public key from a private key
  - Extracting an Elliptic Curve point (EC Point) with coordinates {x, y}
    from a secp256k1 public key
  - Generating a Bitcoin public key from an EC Point
  """

  use Bitwise

  # 256 bits
  @num_secret_bytes 32
  @hex 16
  @greater_than_curve_midpoint_prefix 0x03
  @less_than_curve_midpoint_prefix 0x02
  # Elliptic curve parameter (secp256k1) to determine max private key value
  @n """
     115792089237316195423570985008687907852\
     837564279074904382605163141518161494337\
     """
     |> String.to_integer()
  # Private secret key string as base16
  @example_private_key """
  038109007313a5807b2eccc082c8c3fbb988a973cacf1a7df9ce725c31b14776\
  """

  # Guard to determine whether a generated key is within the Elliptic curve.
  defguardp valid_key?(key) when key in 0..@n

  # Guard to determine whether a given integer is even or not.
  defguardp is_even?(int) when (int &&& 1) == 1

  @doc """
  Function wrapper around the module attribute for an example private key.

  ## Example:

      iex> BitcoinAddress.Secp256k1.example_private_key
      "038109007313a5807b2eccc082c8c3fbb988a973cacf1a7df9ce725c31b14776"
  """
  def example_private_key do
    @example_private_key
  end

  @doc """
  Generates a random private key that has a decimal value within the confines
  of the Secp256k1 Elliptic curve.

  ## Example:

      iex> private_key = BitcoinAddress.Secp256k1.generate_private_key
      iex> private_key_pattern = ~r/\\A[0-9a-f]{64}\\z/
      iex> private_key =~ private_key_pattern
      true
  """
  def generate_private_key do
    with hex_secret <- random_secret(),
         dec_secret <- String.to_integer(hex_secret, @hex) do
      case dec_secret do
        n when valid_key?(n) ->
          hex_secret

        _out_of_range ->
          generate_private_key()
      end
    end
  end

  @doc """
  Function that returns a Bitcoin public key, generated by the secp256k1
  algorithm, from a given private key.

  ## Parameters

    - `private_key`: A string of characters.

  ## Example:

      iex> private_key = BitcoinAddress.Secp256k1.generate_private_key
      iex> public_key = BitcoinAddress.Secp256k1.bitcoin_public_key(private_key)
      iex> public_key_pattern = ~r/\\A[0-9a-f]{66}\\z/
      iex> public_key =~ public_key_pattern
      true
  """
  def bitcoin_public_key(private_key) do
    with {public_key, _private_key} <- public_key_from_private_key(private_key),
         ec_point <- ec_point_from_public_key(public_key),
         bitcoin_public_key <- bitcoin_public_key_from_ec_point(ec_point) do
      bitcoin_public_key
    end
  end

  # Generate a new private key by collecting 256 bits of random data from
  # the OS's cryptographically secure random generator
  defp random_secret do
    @num_secret_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end

  defp public_key_from_private_key(private_key) do
    private_key
    |> String.to_integer(@hex)
    |> (fn int -> :crypto.generate_key(:ecdh, :secp256k1, int) end).()
  end

  # Elliptic Curve point
  defp ec_point_from_public_key(public_key) do
    <<_prefix::size(8), x::size(256), y::size(256)>> = public_key
    {x, y}
  end

  defp bitcoin_public_key_from_ec_point({x, y}) do
    <<public_key_prefix(y)::size(8), x::size(256)>>
    |> Base.encode16(case: :lower)
  end

  defp public_key_prefix(y) when is_even?(y) do
    @greater_than_curve_midpoint_prefix
  end

  defp public_key_prefix(_y) do
    @less_than_curve_midpoint_prefix
  end
end
