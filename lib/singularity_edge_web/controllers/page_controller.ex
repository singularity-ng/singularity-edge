defmodule SingularityEdgeWeb.PageController do
  use SingularityEdgeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
