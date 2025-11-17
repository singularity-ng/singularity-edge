defmodule SingularityEdgeWeb.ACMEController do
  @moduledoc """
  Handles ACME HTTP-01 challenges for Let's Encrypt domain validation.
  """

  use SingularityEdgeWeb, :controller

  alias SingularityEdge.SSL.ACME

  def challenge(conn, %{"token" => token}) do
    case ACME.handle_challenge(token) do
      {:ok, response} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, response)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> text("Challenge not found")
    end
  end
end
